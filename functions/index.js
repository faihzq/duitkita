const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

/**
 * When a new member is added to a group, send them a push notification.
 * Triggers on: groups/{groupId}/members/{memberId} — document created
 */
exports.onMemberAdded = onDocumentCreated(
  { document: "groups/{groupId}/members/{memberId}", region: "asia-southeast1" },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const { groupId, memberId } = event.params;

    // Don't notify the group creator (they added themselves)
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) return;

    const groupData = groupDoc.data();
    const groupName = groupData.name || "Unknown Group";
    const monthlyAmount = groupData.monthlyAmount || 0;

    // Skip if this member is the group creator
    if (groupData.createdBy === memberId) return;

    await sendNotification(memberId, {
      notification: {
        title: `Welcome to ${groupName}!`,
        body: `You have been added to ${groupName}. Monthly amount: RM${monthlyAmount.toFixed(2)}`,
      },
      data: {
        type: "member_added",
        groupId: groupId,
      },
    });
    console.log(`Sent member-added notification to ${memberId} for group ${groupName}`);
  }
);

/**
 * When a payment is created, notify the group admin.
 * If auto-approve is on (payment created as 'confirmed'), also notify the member.
 * Triggers on: payments/{paymentId} — document created
 */
exports.onPaymentCreated = onDocumentCreated(
  { document: "payments/{paymentId}", region: "asia-southeast1" },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const paymentData = snapshot.data();

    // Skip notifications for bulk-imported payments
    if (paymentData.bulkImport === true) return;

    const groupId = paymentData.groupId;
    const payerName = paymentData.userName || "Someone";
    const amount = paymentData.amount || 0;
    const payerUserId = paymentData.userId;
    const paymentStatus = paymentData.paymentStatus || "pending";

    // Get group info
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) return;

    const groupData = groupDoc.data();
    const groupName = groupData.name || "Unknown Group";
    const adminUserId = groupData.createdBy;

    // 1. Notify admin about new payment (unless admin is paying themselves)
    if (payerUserId !== adminUserId) {
      const statusLabel = paymentStatus === "confirmed" ? " (Auto-approved)" : " (Pending review)";
      await sendNotification(adminUserId, {
        notification: {
          title: `Payment Received - ${groupName}`,
          body: `${payerName} paid RM${amount.toFixed(2)}${statusLabel}`,
        },
        data: {
          type: "payment_received",
          groupId: groupId,
          paymentId: event.params.paymentId,
        },
      });
      console.log(`Sent payment notification to admin ${adminUserId} for ${payerName}'s payment in ${groupName}`);
    }

    // 2. If auto-approved, notify the member that payment was confirmed automatically
    if (paymentStatus === "confirmed" && payerUserId !== adminUserId) {
      await sendNotification(payerUserId, {
        notification: {
          title: `Payment Confirmed - ${groupName}`,
          body: `Your payment of RM${amount.toFixed(2)} has been auto-confirmed`,
        },
        data: {
          type: "payment_auto_confirmed",
          groupId: groupId,
          paymentId: event.params.paymentId,
        },
      });
      console.log(`Sent auto-confirm notification to ${payerName} in ${groupName}`);
    }
  }
);

/**
 * When an expense is submitted, notify all group admins to verify it.
 * Triggers on: expenses/{expenseId} — document created
 */
exports.onExpenseSubmitted = onDocumentCreated(
  { document: "expenses/{expenseId}", region: "asia-southeast1" },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const expenseData = snapshot.data();
    const groupId = expenseData.groupId;
    const requesterName = expenseData.requestedByName || "Someone";
    const requesterUserId = expenseData.requestedBy;
    const title = expenseData.title || "Expense";
    const amount = expenseData.amount || 0;

    // Get group info
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) return;

    const groupData = groupDoc.data();
    const groupName = groupData.name || "Unknown Group";

    // Get all admin members
    const membersSnapshot = await db
      .collection("groups")
      .doc(groupId)
      .collection("members")
      .where("isAdmin", "==", true)
      .get();

    // Notify each admin (skip requester if they are also admin)
    for (const memberDoc of membersSnapshot.docs) {
      const adminId = memberDoc.id;
      if (adminId === requesterUserId) continue;

      await sendNotification(adminId, {
        notification: {
          title: `Expense Pending Approval - ${groupName}`,
          body: `${requesterName} submitted "${title}" for RM${amount.toFixed(2)}`,
        },
        data: {
          type: "expense_submitted",
          groupId: groupId,
          expenseId: event.params.expenseId,
        },
      });
    }

    // Fallback: also notify group creator in case they're not in the members subcollection as admin
    const adminUserId = groupData.createdBy;
    const adminAlreadyNotified = membersSnapshot.docs.some((d) => d.id === adminUserId);
    if (!adminAlreadyNotified && adminUserId !== requesterUserId) {
      await sendNotification(adminUserId, {
        notification: {
          title: `Expense Pending Approval - ${groupName}`,
          body: `${requesterName} submitted "${title}" for RM${amount.toFixed(2)}`,
        },
        data: {
          type: "expense_submitted",
          groupId: groupId,
          expenseId: event.params.expenseId,
        },
      });
    }

    console.log(`Sent expense notification to admins for "${title}" in ${groupName}`);
  }
);

/**
 * Helper: send FCM to a user, clean up invalid tokens.
 */
async function sendNotification(userId, message) {
  const userDoc = await db.collection("users").doc(userId).get();
  if (!userDoc.exists) return;

  const fcmToken = userDoc.data().fcmToken;
  if (!fcmToken) return;

  try {
    await getMessaging().send({
      token: fcmToken,
      ...message,
      android: {
        priority: "high",
        notification: {
          channelId: "push_notifications",
          icon: "@mipmap/ic_launcher",
          ...(message.android?.notification || {}),
        },
      },
    });
  } catch (error) {
    console.error(`Error sending notification to ${userId}:`, error);
    if (
      error.code === "messaging/invalid-registration-token" ||
      error.code === "messaging/registration-token-not-registered"
    ) {
      await db.collection("users").doc(userId).update({ fcmToken: null });
    }
  }
}

/**
 * When an expense is approved/rejected, notify the requester
 * and all group members about the expense decision.
 * Triggers on: expenses/{expenseId} — document updated
 */
exports.onExpenseVerified = onDocumentUpdated(
  { document: "expenses/{expenseId}", region: "asia-southeast1" },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // Only trigger when status changes from pending to approved/rejected
    if (before.status === after.status) return;
    if (after.status !== "approved" && after.status !== "rejected") return;

    const groupId = after.groupId;
    const title = after.title || "Expense";
    const amount = after.amount || 0;
    const requesterUserId = after.requestedBy;
    const isApproved = after.status === "approved";

    // Get group info
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) return;

    const groupData = groupDoc.data();
    const groupName = groupData.name || "Unknown Group";

    // 1. Notify the requester about approval/rejection
    const statusText = isApproved ? "Approved" : "Rejected";
    await sendNotification(requesterUserId, {
      notification: {
        title: `Expense ${statusText} - ${groupName}`,
        body: `Your expense "${title}" (RM${amount.toFixed(2)}) has been ${statusText.toLowerCase()}`,
      },
      data: {
        type: "expense_verified",
        groupId: groupId,
        expenseId: event.params.expenseId,
        status: after.status,
      },
    });

    // 2. If approved, notify all group members about the expense from collection
    if (isApproved) {
      const membersSnapshot = await db
        .collection("groups")
        .doc(groupId)
        .collection("members")
        .get();

      const adminUserId = groupData.createdBy;

      for (const memberDoc of membersSnapshot.docs) {
        const memberId = memberDoc.id;
        // Skip the requester (already notified) and the admin who approved
        if (memberId === requesterUserId || memberId === adminUserId) continue;

        await sendNotification(memberId, {
          notification: {
            title: `Expense Approved - ${groupName}`,
            body: `RM${amount.toFixed(2)} from group collection used for "${title}"`,
          },
          data: {
            type: "expense_approved_info",
            groupId: groupId,
            expenseId: event.params.expenseId,
          },
        });
      }

      console.log(`Notified all members about approved expense "${title}" in ${groupName}`);
    }
  }
);

/**
 * When a member is removed from a group, notify them.
 * Triggers on: groups/{groupId}/members/{memberId} — document deleted
 */
exports.onMemberRemoved = onDocumentDeleted(
  { document: "groups/{groupId}/members/{memberId}", region: "asia-southeast1" },
  async (event) => {
    const { groupId, memberId } = event.params;

    // Get group info
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) return;

    const groupData = groupDoc.data();
    const groupName = groupData.name || "Unknown Group";

    // Don't notify if the group is being deleted (admin removing themselves)
    if (groupData.createdBy === memberId) return;

    await sendNotification(memberId, {
      notification: {
        title: `Removed from ${groupName}`,
        body: `You have been removed from ${groupName} by the admin`,
      },
      data: {
        type: "member_removed",
        groupId: groupId,
      },
    });

    console.log(`Notified ${memberId} about removal from ${groupName}`);
  }
);

/**
 * When a payment is verified (confirmed/rejected) by admin, notify the member.
 * Triggers on: payments/{paymentId} — document updated
 */
exports.onPaymentVerified = onDocumentUpdated(
  { document: "payments/{paymentId}", region: "asia-southeast1" },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // Only trigger when paymentStatus changes
    if (before.paymentStatus === after.paymentStatus) return;
    if (after.paymentStatus !== "confirmed" && after.paymentStatus !== "rejected") return;

    const payerUserId = after.userId;
    const payerName = after.userName || "Member";
    const amount = after.amount || 0;
    const groupId = after.groupId;
    const isConfirmed = after.paymentStatus === "confirmed";

    // Get group info
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) return;

    const groupData = groupDoc.data();
    const groupName = groupData.name || "Unknown Group";

    // Don't notify if user verified their own payment (admin paying themselves)
    if (after.verifiedBy === payerUserId) return;

    const statusText = isConfirmed ? "Confirmed" : "Rejected";
    const rejectionReason = after.rejectionReason || "";
    let bodyText;
    if (isConfirmed) {
      bodyText = `Your payment of RM${amount.toFixed(2)} has been confirmed by admin`;
    } else {
      bodyText = rejectionReason
        ? `Your payment of RM${amount.toFixed(2)} has been rejected. Reason: ${rejectionReason}`
        : `Your payment of RM${amount.toFixed(2)} has been rejected. Please contact your admin.`;
    }
    await sendNotification(payerUserId, {
      notification: {
        title: `Payment ${statusText} - ${groupName}`,
        body: bodyText,
      },
      data: {
        type: "payment_verified",
        groupId: groupId,
        paymentId: event.params.paymentId,
        status: after.paymentStatus,
      },
    });

    console.log(`Notified ${payerName} about payment ${statusText.toLowerCase()} in ${groupName}`);
  }
);

/**
 * Daily scheduled payment reminder.
 * Runs every day at 9:00 AM MYT (1:00 AM UTC).
 * Checks all groups where today is the reminderDay,
 * then notifies members who haven't paid this month.
 */
exports.dailyPaymentReminder = onSchedule(
  {
    schedule: "0 1 * * *", // 1:00 AM UTC = 9:00 AM MYT
    timeZone: "Asia/Kuala_Lumpur",
    region: "asia-southeast1",
  },
  async () => {
    const now = new Date();
    const today = now.getDate();
    const currentMonth = now.getMonth() + 1;
    const currentYear = now.getFullYear();

    console.log(`Running daily payment reminder check for day ${today}, month ${currentMonth}/${currentYear}`);

    try {
      // Find all groups where reminderDay matches today
      const groupsSnapshot = await db
        .collection("groups")
        .where("reminderDay", "==", today)
        .get();

      if (groupsSnapshot.empty) {
        console.log("No groups with reminder today");
        return;
      }

      console.log(`Found ${groupsSnapshot.size} groups with reminder on day ${today}`);

      for (const groupDoc of groupsSnapshot.docs) {
        const groupData = groupDoc.data();
        const groupId = groupDoc.id;
        const groupName = groupData.name || "Unknown Group";
        const monthlyAmount = groupData.monthlyAmount || 0;
        const memberIds = groupData.memberIds || [];

        // Get all confirmed payments for this group this month
        const paymentsSnapshot = await db
          .collection("payments")
          .where("groupId", "==", groupId)
          .where("month", "==", currentMonth)
          .where("year", "==", currentYear)
          .where("paymentStatus", "==", "confirmed")
          .get();

        // Collect userIds who already paid
        const paidUserIds = new Set();
        for (const payDoc of paymentsSnapshot.docs) {
          paidUserIds.add(payDoc.data().userId);
        }

        // Also count pending payments (submitted but not yet confirmed)
        const pendingSnapshot = await db
          .collection("payments")
          .where("groupId", "==", groupId)
          .where("month", "==", currentMonth)
          .where("year", "==", currentYear)
          .where("paymentStatus", "==", "pending")
          .get();

        const pendingUserIds = new Set();
        for (const payDoc of pendingSnapshot.docs) {
          pendingUserIds.add(payDoc.data().userId);
        }

        // Notify members who haven't paid or submitted
        for (const memberId of memberIds) {
          if (paidUserIds.has(memberId) || pendingUserIds.has(memberId)) continue;

          await sendNotification(memberId, {
            notification: {
              title: `Payment Reminder - ${groupName}`,
              body: `Jangan lupa bayar yuran RM${monthlyAmount.toFixed(2)} bulan ni untuk ${groupName}!`,
            },
            data: {
              type: "payment_reminder",
              groupId: groupId,
            },
          });
        }

        console.log(`Sent reminders for ${groupName}: ${memberIds.length - paidUserIds.size - pendingUserIds.size} members reminded`);
      }
    } catch (error) {
      console.error("Error in daily payment reminder:", error);
    }
  }
);
