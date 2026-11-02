// Expense Approval / Detail screen
// Current screen shows just amount + name + date. Admins need context to make a decision.
// This redesign adds: receipt preview, requester trust signals, full description, group context,
// itemized split (if applicable), audit trail, and quick action sheets.

const ExpenseApproval = ({ c, d, close }) => {
  const [reviewing, setReviewing] = React.useState(null); // null | 'approve' | 'reject'
  const [rejectNote, setRejectNote] = React.useState('');
  const [receiptOpen, setReceiptOpen] = React.useState(false);

  const expense = {
    title: 'Hari Raya groceries',
    category: 'Food & groceries',
    amount: 248.40,
    date: '18 May 2026',
    time: '14:23',
    description: 'Groceries from Lotus\'s for family gathering. Includes meat, vegetables, drinks and decorations.',
    requester: { name: 'Fairul Haziq', initials: 'FH', role: 'Member', joinedDays: 142, approvedCount: 12, rejectedCount: 1 },
    group: { name: 'Hakim Family', members: 5, emoji: '🏠' },
    receiptUrl: true, // mock
    submittedDaysAgo: 0,
    submittedHoursAgo: 2,
    splitMode: 'equal',
    splitAmong: 5,
  };

  if (reviewing === 'approve') {
    return <ApprovalConfirm c={c} d={d} expense={expense} action="approve" back={() => setReviewing(null)} close={close}/>;
  }
  if (reviewing === 'reject') {
    return <ApprovalConfirm c={c} d={d} expense={expense} action="reject"
      note={rejectNote} setNote={setRejectNote} back={() => setReviewing(null)} close={close}/>;
  }

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: c.bg, overflow: 'hidden' }}>
      {/* Header */}
      <div style={{
        background: c.headerGradient, color: '#fff',
        padding: '14px 16px 22px',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <button onClick={close} style={{ width: 38, height: 38, borderRadius: 11,
            background: 'rgba(255,255,255,0.12)', border: '1px solid rgba(255,255,255,0.15)',
            cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="arrowLeft" size={18} color="#fff"/>
          </button>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 16, fontWeight: 800, letterSpacing: -0.2 }}>Expense review</div>
            <div style={{ fontSize: 11, opacity: 0.65, fontWeight: 500 }}>
              {expense.group.emoji} {expense.group.name} · Submitted {expense.submittedHoursAgo}h ago
            </div>
          </div>
          <div style={{
            padding: '6px 10px', borderRadius: 999,
            background: 'rgba(245,158,11,0.18)', border: '1px solid rgba(245,158,11,0.3)',
            color: c.warning, fontSize: 11, fontWeight: 700, letterSpacing: 0.1,
            display: 'inline-flex', alignItems: 'center', gap: 5,
          }}>
            <span style={{ width: 6, height: 6, borderRadius: 3, background: c.warning,
              animation: 'pulse 2s ease-in-out infinite' }}/>
            Pending
          </div>
        </div>
      </div>

      {/* Scrollable */}
      <div style={{ flex: 1, overflow: 'auto', padding: '0 16px 24px' }}>
        {/* Hero card — amount + title */}
        <div style={{ marginTop: -10, marginBottom: 14 }}>
          <div style={{
            background: c.surface, border: `1px solid ${c.border}`,
            borderRadius: 18, padding: 18, boxShadow: c.shadowLg,
          }}>
            <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5,
              padding: '3px 8px', borderRadius: 6, background: c.catBillsSoft,
              fontSize: 10, fontWeight: 700, color: c.catBills, letterSpacing: 0.3,
              textTransform: 'uppercase' }}>
              <Icon name="receipt" size={11}/> {expense.category}
            </div>
            <div style={{ fontSize: 18, fontWeight: 800, color: c.text, marginTop: 8, letterSpacing: -0.3 }}>
              {expense.title}
            </div>
            <div style={{ fontSize: 40, fontWeight: 800, color: c.text, marginTop: 6,
              letterSpacing: -1.4, lineHeight: 1, fontFamily: 'Manrope, ui-monospace' }}>
              RM {expense.amount.toFixed(2)}
            </div>
            <div style={{ marginTop: 10, paddingTop: 10, borderTop: `1px solid ${c.border}`,
              display: 'flex', alignItems: 'center', gap: 14, fontSize: 11, color: c.textSecondary, fontWeight: 600 }}>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                <Icon name="calendar" size={13}/> {expense.date}
              </span>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                <Icon name="clock" size={13}/> {expense.time}
              </span>
            </div>
          </div>
        </div>

        {/* Requester card */}
        <SectionLabel c={c}>Requested by</SectionLabel>
        <div style={{
          background: c.surface, border: `1px solid ${c.border}`,
          borderRadius: 16, padding: 14, marginBottom: 14,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <Avatar name={expense.requester.name} size={44}/>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 15, fontWeight: 800, color: c.text, letterSpacing: -0.2 }}>
                {expense.requester.name}
              </div>
              <div style={{ fontSize: 11, color: c.textSecondary, fontWeight: 500 }}>
                {expense.requester.role} · Joined {expense.requester.joinedDays} days ago
              </div>
            </div>
            <button style={{ width: 36, height: 36, borderRadius: 10,
              background: c.surfaceAlt, border: `1px solid ${c.border}`, cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="phone" size={16} color={c.text}/>
            </button>
          </div>
          {/* Trust signals */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginTop: 12 }}>
            <TrustStat c={c} icon="checkCircle" iconColor={c.success}
              label="Approved" value={expense.requester.approvedCount}/>
            <TrustStat c={c} icon="close" iconColor={c.danger}
              label="Rejected" value={expense.requester.rejectedCount}/>
          </div>
        </div>

        {/* Receipt preview */}
        <SectionLabel c={c}>Receipt</SectionLabel>
        <button onClick={() => setReceiptOpen(true)} style={{
          width: '100%', background: c.surface, border: `1px solid ${c.border}`,
          borderRadius: 16, padding: 12, marginBottom: 14, cursor: 'pointer',
          display: 'flex', gap: 12, alignItems: 'center', fontFamily: 'inherit', textAlign: 'left',
        }}>
          {/* Mock receipt thumbnail */}
          <div style={{
            width: 72, height: 90, borderRadius: 10, flexShrink: 0,
            background: '#fff', border: `1px solid ${c.border}`, padding: 7,
            display: 'flex', flexDirection: 'column', gap: 3, overflow: 'hidden',
            position: 'relative',
          }}>
            <div style={{ height: 5, borderRadius: 1, background: c.text, width: '50%' }}/>
            <div style={{ height: 2, borderRadius: 1, background: c.borderStrong, width: '70%' }}/>
            <div style={{ height: 2, borderRadius: 1, background: c.borderStrong, width: '40%' }}/>
            <div style={{ height: 1 }}/>
            {[0,1,2,3].map(i => (
              <div key={i} style={{ display: 'flex', gap: 4 }}>
                <div style={{ height: 2, borderRadius: 1, background: c.surfaceAlt, flex: 2 }}/>
                <div style={{ height: 2, borderRadius: 1, background: c.surfaceAlt, flex: 1 }}/>
              </div>
            ))}
            <div style={{ height: 1, background: c.borderStrong, margin: '3px 0' }}/>
            <div style={{ display: 'flex', gap: 3 }}>
              <div style={{ height: 4, borderRadius: 1, background: c.text, flex: 1 }}/>
              <div style={{ height: 4, borderRadius: 1, background: c.text, flex: 1 }}/>
            </div>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: c.text }}>receipt_lotuss_240518.jpg</div>
            <div style={{ fontSize: 11, color: c.textSecondary, marginTop: 2 }}>284 KB · Tap to expand</div>
            <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
              <Pill c={c} bg={c.successSoft} color={c.success}>
                <Icon name="check" size={10} strokeWidth={3}/> OCR matched
              </Pill>
            </div>
          </div>
          <Icon name="chevronRight" size={18} color={c.textTertiary}/>
        </button>

        {/* Description */}
        <SectionLabel c={c}>Description</SectionLabel>
        <div style={{
          background: c.surface, border: `1px solid ${c.border}`,
          borderRadius: 16, padding: 14, marginBottom: 14,
          fontSize: 13, color: c.text, lineHeight: 1.5, fontWeight: 500,
        }}>
          {expense.description}
        </div>

        {/* Split breakdown */}
        <SectionLabel c={c}>Split</SectionLabel>
        <div style={{
          background: c.surface, border: `1px solid ${c.border}`,
          borderRadius: 16, padding: 14, marginBottom: 14,
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
            <span style={{ fontSize: 13, fontWeight: 700, color: c.text }}>Equal split · {expense.splitAmong} members</span>
            <span style={{ fontSize: 13, fontWeight: 800, color: c.text, letterSpacing: -0.2 }}>
              RM {(expense.amount / expense.splitAmong).toFixed(2)} <span style={{ fontSize: 10, color: c.textTertiary, fontWeight: 600 }}>each</span>
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
            {['AH', 'FH', 'MS', 'AA', 'KN'].map((init, i) => (
              <div key={i} style={{
                width: 30, height: 30, borderRadius: 8,
                background: c.surfaceAlt, color: c.text,
                fontSize: 11, fontWeight: 800,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                marginLeft: i ? -4 : 0, border: `2px solid ${c.surface}`,
              }}>{init}</div>
            ))}
            <span style={{ marginLeft: 6, fontSize: 11, color: c.textSecondary, fontWeight: 600 }}>
              All members of {expense.group.name}
            </span>
          </div>
        </div>

        {/* Audit trail */}
        <SectionLabel c={c}>History</SectionLabel>
        <div style={{
          background: c.surface, border: `1px solid ${c.border}`,
          borderRadius: 16, padding: 14, marginBottom: 14,
        }}>
          <TimelineItem c={c} icon="upload" iconBg={c.accentSoft} iconColor={c.accentDeep}
            title="Expense submitted" subtitle={`${expense.requester.name} · ${expense.submittedHoursAgo}h ago`} first/>
          <TimelineItem c={c} icon="eye" iconBg={c.surfaceAlt} iconColor={c.textSecondary}
            title="Opened by you" subtitle="Just now" last/>
        </div>

        <div style={{ height: 80 }}/>
      </div>

      {/* Sticky footer — review actions */}
      <div style={{
        background: c.surface, borderTop: `1px solid ${c.border}`,
        padding: '12px 16px 14px',
        boxShadow: '0 -8px 24px rgba(11,31,58,0.06)',
      }}>
        <div style={{ display: 'flex', gap: 10 }}>
          <button onClick={() => setReviewing('reject')} style={{
            flex: 1, height: 52, borderRadius: 14,
            background: c.dangerSoft, color: c.danger, border: 'none',
            cursor: 'pointer', display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            gap: 6, fontSize: 14, fontWeight: 800, letterSpacing: -0.2, fontFamily: 'inherit',
          }}>
            <Icon name="close" size={16} strokeWidth={2.4}/> Reject
          </button>
          <button onClick={() => setReviewing('approve')} style={{
            flex: 2, height: 52, borderRadius: 14,
            background: c.accent, color: '#003830', border: 'none',
            cursor: 'pointer', display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            gap: 6, fontSize: 14, fontWeight: 800, letterSpacing: -0.2, fontFamily: 'inherit',
            boxShadow: `0 8px 20px ${c.accent}50`,
          }}>
            <Icon name="check" size={16} strokeWidth={2.6}/> Approve · RM {expense.amount.toFixed(2)}
          </button>
        </div>
      </div>

      {/* Receipt lightbox */}
      {receiptOpen && (
        <div onClick={() => setReceiptOpen(false)} style={{
          position: 'absolute', inset: 0, background: 'rgba(7,12,24,0.85)', backdropFilter: 'blur(8px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 200, padding: 20,
        }}>
          <button onClick={() => setReceiptOpen(false)} style={{
            position: 'absolute', top: 40, right: 16, width: 40, height: 40, borderRadius: 12,
            background: 'rgba(255,255,255,0.15)', border: '1px solid rgba(255,255,255,0.2)',
            cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1,
          }}>
            <Icon name="close" size={20} color="#fff"/>
          </button>
          <div style={{
            width: '100%', maxWidth: 320, aspectRatio: '0.75',
            background: '#fff', borderRadius: 12, padding: 22,
            display: 'flex', flexDirection: 'column', gap: 6,
            fontFamily: 'ui-monospace, monospace', color: '#222',
          }}>
            <div style={{ fontSize: 16, fontWeight: 800, letterSpacing: 0.5 }}>LOTUS'S MID VALLEY</div>
            <div style={{ fontSize: 10, color: '#666' }}>Lot M2-G, Mid Valley Megamall, KL</div>
            <div style={{ fontSize: 10, color: '#666', marginBottom: 8 }}>Receipt #240518-14238</div>
            <div style={{ height: 1, borderTop: '1px dashed #999', margin: '4px 0' }}/>
            {[
              ['Daging lembu 1kg', '52.90'],
              ['Ayam segar 2kg', '38.00'],
              ['Bawang besar 2kg', '14.80'],
              ['Daun ketumbar', '6.50'],
              ['Minyak masak 5L', '37.90'],
              ['Beras Jasmine 10kg', '52.00'],
              ['Air mineral 1.5L x 6', '14.40'],
              ['Decorations', '31.90'],
            ].map((r, i) => (
              <div key={i} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11 }}>
                <span>{r[0]}</span><span>RM {r[1]}</span>
              </div>
            ))}
            <div style={{ height: 1, borderTop: '1px dashed #999', margin: '6px 0' }}/>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, fontWeight: 800 }}>
              <span>TOTAL</span><span>RM 248.40</span>
            </div>
            <div style={{ marginTop: 'auto', fontSize: 9, color: '#999', textAlign: 'center' }}>
              Thank you · Terima kasih
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

const TrustStat = ({ c, icon, iconColor, label, value }) => (
  <div style={{
    padding: 10, borderRadius: 10, background: c.surfaceAlt,
    display: 'flex', alignItems: 'center', gap: 8,
  }}>
    <Icon name={icon} size={16} color={iconColor}/>
    <div>
      <div style={{ fontSize: 14, fontWeight: 800, color: c.text, lineHeight: 1 }}>{value}</div>
      <div style={{ fontSize: 10, color: c.textSecondary, fontWeight: 600, marginTop: 2 }}>{label}</div>
    </div>
  </div>
);

const TimelineItem = ({ c, icon, iconBg, iconColor, title, subtitle, first, last }) => (
  <div style={{ display: 'flex', gap: 12, position: 'relative' }}>
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div style={{
        width: 28, height: 28, borderRadius: 8, background: iconBg,
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, zIndex: 1,
      }}>
        <Icon name={icon} size={13} color={iconColor}/>
      </div>
      {!last && <div style={{ flex: 1, width: 1.5, background: c.border, marginTop: 2 }}/>}
    </div>
    <div style={{ paddingBottom: last ? 0 : 12, paddingTop: first ? 0 : 2, flex: 1 }}>
      <div style={{ fontSize: 13, fontWeight: 700, color: c.text }}>{title}</div>
      <div style={{ fontSize: 11, color: c.textSecondary, marginTop: 1 }}>{subtitle}</div>
    </div>
  </div>
);

// Approve / Reject confirmation sheet
const ApprovalConfirm = ({ c, d, expense, action, note, setNote, back, close }) => {
  const isApprove = action === 'approve';
  const canSubmit = isApprove || (note && note.trim().length >= 3);
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: c.bg, overflow: 'hidden' }}>
      <div style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
        <button onClick={back} style={{ width: 38, height: 38, borderRadius: 11,
          background: c.surface, border: `1px solid ${c.border}`, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="arrowLeft" size={18} color={c.text}/>
        </button>
        <div style={{ fontSize: 16, fontWeight: 800, color: c.text, letterSpacing: -0.2 }}>
          {isApprove ? 'Confirm approval' : 'Reject expense'}
        </div>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '0 16px' }}>
        <div style={{
          textAlign: 'center', padding: '20px 0 8px',
        }}>
          <div style={{
            width: 64, height: 64, borderRadius: 20,
            background: isApprove ? c.accentSoft : c.dangerSoft,
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center', marginBottom: 12,
          }}>
            <Icon name={isApprove ? 'check' : 'close'} size={28}
              color={isApprove ? c.accentDeep : c.danger} strokeWidth={2.4}/>
          </div>
          <div style={{ fontSize: 22, fontWeight: 800, color: c.text, letterSpacing: -0.4 }}>
            {isApprove ? `Approve RM ${expense.amount.toFixed(2)}?` : `Reject this expense?`}
          </div>
          <div style={{ fontSize: 13, color: c.textSecondary, marginTop: 6, maxWidth: 280, margin: '6px auto 0' }}>
            {isApprove
              ? `${expense.requester.name} will be notified and the expense will be recorded against ${expense.group.name}.`
              : `${expense.requester.name} will see your reason and can resubmit with changes.`}
          </div>
        </div>

        <div style={{
          background: c.surface, border: `1px solid ${c.border}`,
          borderRadius: 16, padding: 14, marginTop: 16,
        }}>
          <ReviewRow c={c} label="Expense" value={expense.title}/>
          <ReviewRow c={c} label="Amount" value={`RM ${expense.amount.toFixed(2)}`} emphasize/>
          <ReviewRow c={c} label="Requester" value={expense.requester.name}/>
          <ReviewRow c={c} label="Group" value={expense.group.name}/>
          <ReviewRow c={c} label="Per member" value={`RM ${(expense.amount / expense.splitAmong).toFixed(2)}`} last/>
        </div>

        {!isApprove && (
          <>
            <div style={{ fontSize: 10, fontWeight: 700, color: c.textSecondary,
              textTransform: 'uppercase', letterSpacing: 0.5, margin: '16px 4px 8px' }}>
              Reason · required
            </div>
            <div style={{
              background: c.surface, border: `1px solid ${c.border}`,
              borderRadius: 16, padding: '12px 14px',
            }}>
              <textarea value={note || ''} onChange={e => setNote(e.target.value)}
                placeholder="e.g. Receipt unclear, please resubmit with itemized photo" rows={3}
                style={{
                  width: '100%', border: 'none', outline: 'none', background: 'none',
                  fontSize: 13, fontWeight: 500, color: c.text, fontFamily: 'inherit',
                  resize: 'none', padding: 0, lineHeight: 1.5,
                }}/>
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 10 }}>
              {[
                'Receipt unclear', 'Wrong amount', 'Not group-related', 'Need more detail',
              ].map(t => (
                <button key={t} onClick={() => setNote((note ? note + ' · ' : '') + t)} style={{
                  padding: '6px 10px', borderRadius: 999,
                  background: c.surface, border: `1px solid ${c.border}`,
                  fontSize: 11, fontWeight: 600, color: c.text, cursor: 'pointer', fontFamily: 'inherit',
                }}>+ {t}</button>
              ))}
            </div>
          </>
        )}

        <div style={{ height: 100 }}/>
      </div>

      <div style={{
        background: c.surface, borderTop: `1px solid ${c.border}`,
        padding: '12px 16px 14px', display: 'flex', gap: 10,
      }}>
        <button onClick={back} style={{
          flex: 1, height: 52, borderRadius: 14,
          background: c.surface, color: c.text, border: `1px solid ${c.border}`,
          cursor: 'pointer', fontSize: 14, fontWeight: 700, fontFamily: 'inherit',
        }}>Cancel</button>
        <button disabled={!canSubmit} onClick={close} style={{
          flex: 2, height: 52, borderRadius: 14,
          background: !canSubmit ? c.surfaceAlt : isApprove ? c.accent : c.danger,
          color: !canSubmit ? c.textTertiary : isApprove ? '#003830' : '#fff',
          border: 'none', cursor: canSubmit ? 'pointer' : 'not-allowed',
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 6,
          fontSize: 14, fontWeight: 800, letterSpacing: -0.2, fontFamily: 'inherit',
        }}>
          <Icon name={isApprove ? 'check' : 'close'} size={16} strokeWidth={2.6}/>
          {isApprove ? 'Approve & record' : 'Reject & notify'}
        </button>
      </div>
    </div>
  );
};

const ReviewRow = ({ c, label, value, emphasize, last }) => (
  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center',
    padding: '10px 0', borderBottom: last ? 'none' : `1px solid ${c.border}` }}>
    <span style={{ fontSize: 12, color: c.textSecondary, fontWeight: 600 }}>{label}</span>
    <span style={{ fontSize: emphasize ? 16 : 13, fontWeight: emphasize ? 800 : 700,
      color: c.text, letterSpacing: emphasize ? -0.3 : 0 }}>{value}</span>
  </div>
);

window.ExpenseApproval = ExpenseApproval;
