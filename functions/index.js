const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getStorage } = require("firebase-admin/storage");
const crypto = require("crypto");
const sharp = require("sharp");

// Google Maps Routes key — set with:
//   firebase functions:secrets:set MAPS_API_KEY
const MAPS_API_KEY = defineSecret("MAPS_API_KEY");

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
        // Caller extras (ttl, collapseKey) survive; notification is merged below.
        ...(message.android || {}),
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

        // Settled groups have reached their goal — no more monthly collection.
        if (groupData.isSettled === true) continue;

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

/**
 * When a fund-loan request is created (status 'pending'), notify the group's
 * admins so they can approve/reject it.
 * Triggers on: fund_loans/{loanId} — document created
 */
exports.onFundLoanCreated = onDocumentCreated(
  { document: "fund_loans/{loanId}", region: "asia-southeast1" },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const loan = snapshot.data();
    // Only pending requests need admin attention (admins may create pre-approved loans).
    if ((loan.status || "pending") !== "pending") return;

    const groupId = loan.groupId;
    const borrower = loan.borrowerName || "A member";
    const amount = loan.principal || 0;
    const title = loan.title || "";
    const requesterId = loan.createdBy;

    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) return;
    const groupName = groupDoc.data().name || "Unknown Group";

    // Notify every admin of the group except the requester.
    const membersSnapshot = await db
      .collection("groups").doc(groupId).collection("members")
      .where("isAdmin", "==", true).get();

    for (const memberDoc of membersSnapshot.docs) {
      const adminId = memberDoc.id;
      if (adminId === requesterId) continue;
      await sendNotification(adminId, {
        notification: {
          title: `Loan Request - ${groupName}`,
          body: `${borrower} requested RM${amount.toFixed(2)} (${title})`,
        },
        data: { type: "fund_loan_requested", groupId: groupId, loanId: event.params.loanId },
      });
    }
    console.log(`Notified admins of fund-loan request in ${groupName}`);
  }
);

/**
 * When a fund-loan's status changes to approved/rejected, notify the borrower.
 * Triggers on: fund_loans/{loanId} — document updated
 */
exports.onFundLoanUpdated = onDocumentUpdated(
  { document: "fund_loans/{loanId}", region: "asia-southeast1" },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status === after.status) return;
    if (after.status !== "approved" && after.status !== "rejected") return;

    const borrowerId = after.borrowerId;
    const amount = after.principal || 0;
    const title = after.title || "";
    const isApproved = after.status === "approved";

    await sendNotification(borrowerId, {
      notification: {
        title: isApproved ? "Loan Approved 🎉" : "Loan Rejected",
        body: isApproved
          ? `Your request for RM${amount.toFixed(2)} ("${title}") was approved`
          : `Your request for "${title}" was rejected`,
      },
      data: {
        type: "fund_loan_decision",
        groupId: after.groupId || "",
        loanId: event.params.loanId,
        status: after.status,
      },
    });
    console.log(`Notified borrower ${borrowerId} of fund-loan ${after.status}`);
  }
);

/**
 * Daily scheduled debt/bill reminder.
 * Runs every day at 9:00 AM MYT (1:00 AM UTC). For each active debt/bill that
 * hasn't been paid this month, notifies the owner the day before it's due
 * ("due tomorrow") and on the due day ("due today").
 */
exports.dailyDebtBillReminder = onSchedule(
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

    console.log(`Running daily debt/bill reminder for day ${today}`);

    try {
      const debtsSnapshot = await db
        .collection("debts")
        .where("isActive", "==", true)
        .get();

      if (debtsSnapshot.empty) {
        console.log("No active debts/bills");
        return;
      }

      for (const debtDoc of debtsSnapshot.docs) {
        const d = debtDoc.data();
        const dueDay = d.dueDay || 1;
        // Remind the day before (or on the day itself when dueDay is the 1st).
        const dayBefore = dueDay > 1 ? dueDay - 1 : dueDay;
        if (today !== dayBefore && today !== dueDay) continue;

        // Skip if already paid this month.
        const paidSnapshot = await db
          .collection("debts").doc(debtDoc.id).collection("payments")
          .where("month", "==", currentMonth)
          .where("year", "==", currentYear)
          .limit(1).get();
        if (!paidSnapshot.empty) continue;

        const isBill = (d.type || "debt") === "bill";
        const label = isBill ? "Bill" : "Loan";
        const emoji = isBill ? "📋" : "💳";
        const title = d.title || "Payment";
        const amount = d.monthlyPayment || 0;
        const when = today === dueDay ? "due today" : "due tomorrow";

        await sendNotification(d.userId, {
          notification: {
            title: `${label} Reminder - ${title} ${emoji}`,
            body: `${isBill ? "Bil" : "Hutang"} "${title}" RM${amount.toFixed(2)} ${when}!`,
          },
          data: { type: "debt_bill_reminder", debtId: debtDoc.id },
        });
      }
      console.log("Debt/bill reminders sent");
    } catch (error) {
      console.error("Error in daily debt/bill reminder:", error);
    }
  }
);

// ─── Trip leg estimates (Google Routes API) ──────────────────────────────────

/**
 * Drive time and distance between two consecutive itinerary stops.
 *
 * The API key lives here rather than in the app: Routes is a Web Service API
 * and only supports IP restrictions, so a key shipped inside the APK could be
 * extracted and billed to us.
 *
 * Request:  { origin, destination, departureTime? }
 *           origin/destination are either "lat,lng" or free text.
 *           departureTime is RFC3339 and must be in the future; when supplied
 *           the estimate is traffic-aware for that moment.
 * Response: { minutes, km }
 */
exports.computeLeg = onCall(
  { region: "asia-southeast1", secrets: [MAPS_API_KEY] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to estimate drive times.");
    }

    const origin = (request.data?.origin || "").trim();
    const destination = (request.data?.destination || "").trim();
    if (!origin || !destination) {
      throw new HttpsError(
        "invalid-argument",
        "Both an origin and a destination are required."
      );
    }

    // Only send a departure time we know is ahead of now — the Routes API
    // rejects a past one, and traffic data is meaningless for it anyway.
    let departureTime = request.data?.departureTime || null;
    if (departureTime && new Date(departureTime) <= new Date()) {
      departureTime = null;
    }

    const body = {
      origin: toWaypoint(origin),
      destination: toWaypoint(destination),
      travelMode: "DRIVE",
      routingPreference: departureTime ? "TRAFFIC_AWARE" : "TRAFFIC_UNAWARE",
      ...(departureTime ? { departureTime } : {}),
    };

    let response;
    try {
      response = await fetch(
        "https://routes.googleapis.com/directions/v2:computeRoutes",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": MAPS_API_KEY.value(),
            // Billed by the fields requested — ask for only these two.
            "X-Goog-FieldMask": "routes.duration,routes.distanceMeters",
          },
          body: JSON.stringify(body),
        }
      );
    } catch (error) {
      console.error("Routes API unreachable:", error);
      throw new HttpsError("unavailable", "Could not reach Google Maps.");
    }

    if (!response.ok) {
      const detail = await response.text();
      console.error("Routes API error", response.status, detail);
      throw new HttpsError("internal", "Google Maps could not plan that route.");
    }

    const json = await response.json();
    const route = json.routes && json.routes[0];
    if (!route) {
      // No drivable route — a ferry crossing, or an address that didn't resolve.
      throw new HttpsError(
        "not-found",
        "No driving route between those two places."
      );
    }

    // duration arrives as a protobuf duration string, e.g. "5400s".
    const seconds = parseInt(String(route.duration || "0").replace("s", ""), 10);
    return {
      minutes: Math.round((seconds || 0) / 60),
      km: Math.round(((route.distanceMeters || 0) / 1000) * 10) / 10,
    };
  }
);

/** "2.0453,102.5689" becomes a precise point; anything else is geocoded text. */
function toWaypoint(value) {
  const match = value.match(/^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/);
  if (match) {
    return {
      location: {
        latLng: {
          latitude: parseFloat(match[1]),
          longitude: parseFloat(match[2]),
        },
      },
    };
  }
  return { address: value };
}

// ─── JDT match reminders ─────────────────────────────────────────────────────

/** Kept in step with FootballTeam in lib/services/match_service.dart. */
const FOLLOWED_TEAMS = [
  { id: "139018", label: "JDT" },
  { id: "140138", label: "Malaysia" },
];
const KL_ZONE = "Asia/Kuala_Lumpur";

/**
 * Fixtures come from TheSportsDB's JSON API, not the team page the app
 * scrapes. The free tier returns only the single next event — a hard limit for
 * the app's five-match list, but exactly what a reminder needs, and it does not
 * break every time the site reworks its HTML.
 */
const nextEventUrl = (teamId) =>
  `https://www.thesportsdb.com/api/v1/json/123/eventsnext.php?id=${teamId}`;

/** Calendar date and hour in Malaysia, which is what "match day" means here. */
function malaysianParts(date) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-GB", {
      timeZone: KL_ZONE,
      hourCycle: "h23",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
    })
      .formatToParts(date)
      .map((p) => [p.type, p.value])
  );
  return {
    day: `${parts.year}-${parts.month}-${parts.day}`,
    hour: Number(parts.hour),
  };
}

/** "6:00 PM" — the 12-hour clock the app shows everywhere else. */
function malaysianTime(date) {
  return new Intl.DateTimeFormat("en-US", {
    timeZone: KL_ZONE,
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  }).format(date);
}

/**
 * Which reminder, if any, this run should send.
 *
 * The job wakes on the hour, so "an hour before kick-off" has to be a window
 * rather than a moment: 60–120 minutes catches every fixture exactly once
 * however its kick-off minutes fall. Kick-off wins over match-day so a 10am
 * fixture does not fire both at once.
 */
function reminderKind(now, kickoff) {
  const minutesAway = (kickoff.getTime() - now.getTime()) / 60000;
  if (minutesAway >= 60 && minutesAway < 120) return "kickoff";

  const here = malaysianParts(now);
  const there = malaysianParts(kickoff);
  if (here.hour === 9 && here.day === there.day && minutesAway > 0) {
    return "matchday";
  }
  return null;
}

/**
 * The followed side by its short name, the other by its full one, in the
 * home-vs-away order a fixture list uses: "Jeonbuk Hyundai Motors vs JDT".
 */
function fixtureLine(event, team) {
  const home = event.idHomeTeam === team.id ? team.label : event.strHomeTeam;
  const away = event.idAwayTeam === team.id ? team.label : event.strAwayTeam;
  return `${home} vs ${away}`;
}

/**
 * Short, glanceable copy: the title alone says who and when; the body adds
 * the fixture, competition and ground for anyone who expands it.
 */
function reminderMessage(event, kickoff, kind, team) {
  const time = malaysianTime(kickoff);
  const fixture = fixtureLine(event, team);
  const details = [event.strLeague, event.strVenue].filter(Boolean).join(" · ");

  if (kind === "kickoff") {
    return {
      title: `⏱️ ${team.label} kick off in 1 hour`,
      body: [`${fixture} at ${time}`, event.strLeague]
        .filter(Boolean)
        .join(" · "),
    };
  }
  return {
    title: `⚽ ${team.label} play today at ${time}`,
    body: [fixture, details].filter(Boolean).join(" · "),
  };
}

/**
 * Both crests side by side, home on the left, for the notification's big
 * picture. Drawn once per fixture and kept in Storage; a download-token URL
 * lets FCM fetch it without opening the bucket. Null on any failure — the
 * reminder still goes out, just without a picture.
 *
 * No text on the image: the function's runtime has no reliable fonts, and
 * the notification already says who is playing.
 */
async function crestImageUrl(event) {
  try {
    const bucket = getStorage().bucket();
    const file = bucket.file(`notifications/jdt/${event.idEvent}.png`);

    const [exists] = await file.exists();
    if (exists) {
      const [meta] = await file.getMetadata();
      const token = meta.metadata?.firebaseStorageDownloadTokens;
      if (token) return downloadUrl(bucket.name, file.name, token);
    }

    const image = await drawCrests(event);
    if (!image) return null;

    const token = crypto.randomUUID();
    await file.save(image, {
      contentType: "image/png",
      metadata: {
        cacheControl: "public, max-age=604800",
        metadata: { firebaseStorageDownloadTokens: token },
      },
    });
    return downloadUrl(bucket.name, file.name, token);
  } catch (error) {
    console.error("Could not build the crest image:", error);
    return null;
  }
}

/** The crest picture as PNG bytes, or null when a badge is missing. */
async function drawCrests(event) {
  const badges = [event.strHomeTeamBadge, event.strAwayTeamBadge];
  if (badges.some((b) => !b)) return null;

  // Kept small and central: collapsed, Android shows the picture as a square
  // thumbnail cut from the middle, which must still hold both crests.
  const size = 230;
  const gap = 40;
  const crests = await Promise.all(
    badges.map(async (url) => {
      const response = await fetch(url);
      if (!response.ok) throw new Error(`badge HTTP ${response.status}`);
      return sharp(Buffer.from(await response.arrayBuffer()))
        .resize(size, size, { fit: "contain", background: TRANSPARENT })
        .png()
        .toBuffer();
    })
  );

  // 2:1 suits Android's big-picture layout. Navy matches the app's hero.
  const width = 1024;
  const height = 512;
  const top = (height - size) / 2;
  const left = (width - (size * 2 + gap)) / 2;
  const dot = Buffer.from(
    `<svg width="${width}" height="${height}">` +
      `<circle cx="${width / 2}" cy="${height / 2}" r="6" fill="#ffffff" fill-opacity="0.55"/>` +
      "</svg>"
  );
  return sharp({
    create: { width, height, channels: 4, background: "#0b1f3a" },
  })
    .composite([
      { input: crests[0], left, top },
      { input: crests[1], left: left + size + gap, top },
      { input: dot, left: 0, top: 0 },
    ])
    .png()
    .toBuffer();
}

const TRANSPARENT = { r: 0, g: 0, b: 0, alpha: 0 };

const downloadUrl = (bucket, path, token) =>
  `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/` +
  `${encodeURIComponent(path)}?alt=media&token=${token}`;

/**
 * Sends at most two pushes per fixture: one on the morning of the match, one an
 * hour before kick-off.
 *
 * One hourly job rather than two cron entries — Cloud Scheduler's free tier
 * covers three jobs and the payment and debt reminders already use two.
 */
exports.jdtMatchReminder = onSchedule(
  {
    schedule: "0 * * * *", // every hour, on the hour
    timeZone: KL_ZONE,
    region: "asia-southeast1",
  },
  async () => {
    // One recipient query for both teams: whoever wants reminders wants them
    // for every side the app follows.
    const recipients = await db
      .collection("users")
      .where("notifyJdtMatches", "==", true)
      .get();

    if (recipients.empty) {
      console.log("Nobody has match reminders on");
      return;
    }

    for (const team of FOLLOWED_TEAMS) {
      try {
        await remindForTeam(team, recipients);
      } catch (error) {
        // One team's failure must not silence the other.
        console.error(`${team.label} reminder failed:`, error);
      }
    }
  }
);

async function remindForTeam(team, recipients) {
  let event;
  try {
    const response = await fetch(nextEventUrl(team.id));
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const payload = await response.json();
    event = (payload.events || [])[0];
  } catch (error) {
    console.error(`Could not fetch the next ${team.label} fixture:`, error);
    return;
  }

  // Normal between windows for a national side, and at the end of a season.
  if (!event) {
    console.log(`No upcoming ${team.label} fixture`);
    return;
  }

  // strTimestamp is UTC but carries no zone suffix, so say so explicitly
  // rather than letting Node read it as server-local time.
  const kickoff = new Date(`${event.strTimestamp}Z`);
  if (Number.isNaN(kickoff.getTime())) {
    console.error("Unparseable kick-off time:", event.strTimestamp);
    return;
  }

  const kind = reminderKind(new Date(), kickoff);
  if (!kind) return;

  // Claim the reminder before sending. create() fails if the document is
  // already there, which makes the guard atomic against a retried or
  // overlapping run — better a dropped reminder than a duplicated one. Event
  // ids are unique across teams, so the two never collide.
  const marker = db.collection("jdt_reminders").doc(`${event.idEvent}_${kind}`);
  try {
    await marker.create({
      eventId: event.idEvent,
      teamId: team.id,
      kind,
      kickoff,
      sentAt: new Date(),
    });
  } catch (error) {
    if (error.code === 6 /* ALREADY_EXISTS */) return;
    console.error("Could not claim the reminder:", error);
    return;
  }

  const message = reminderMessage(event, kickoff, kind, team);
  const image = await crestImageUrl(event);
  // Useless once the match has started, so let FCM drop it rather than
  // deliver it late to a phone that was off. At least a minute, in case the
  // run is late and kick-off is very close.
  const ttl = Math.max(kickoff.getTime() - Date.now(), 60 * 1000);

  for (const userDoc of recipients.docs) {
    await sendNotification(userDoc.id, {
      notification: { ...message, ...(image ? { imageUrl: image } : {}) },
      android: {
        ttl,
        notification: {
          channelId: "match_reminders",
          // Same tag for both reminders of a fixture: the kick-off one
          // replaces the morning one instead of stacking under it.
          tag: `jdt_${event.idEvent}`,
        },
      },
      apns: {
        headers: {
          "apns-expiration": String(Math.floor(kickoff.getTime() / 1000)),
          "apns-collapse-id": `jdt_${event.idEvent}`,
        },
        payload: { aps: { "mutable-content": 1 } },
        ...(image ? { fcmOptions: { imageUrl: image } } : {}),
      },
      data: {
        type: "jdt_match",
        eventId: String(event.idEvent),
        teamId: team.id,
        kind,
      },
    });
  }

  console.log(
    `Sent ${team.label} ${kind} reminder for event ${event.idEvent} ` +
      `to ${recipients.size} users`
  );
}

// Exported for local checks of the timing rules, which are the fiddly part.
exports._jdtInternals = { reminderKind, reminderMessage, drawCrests };
