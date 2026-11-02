// New Expense screen — redesigned fields
// Improvements vs. current screen:
// 1. Big amount-first hero (the most important field becomes the focal point)
// 2. Floating labels (instead of placeholder-as-label, which disappears on type)
// 3. Inline helpers + char counters where useful
// 4. Receipt → segmented action with clear primary path (Camera)
// 5. Submit button shows live amount, sticky footer w/ safe gradient fade

const NEField = ({ c, label, value, onChange, hint, leading, trailing, multiline, optional, maxLen }) => {
  const [focused, setFocused] = React.useState(false);
  const filled = value && value.length > 0;
  const active = focused || filled;
  return (
    <div style={{ marginBottom: 12 }}>
      <div style={{
        position: 'relative', background: c.surface,
        border: `1.5px solid ${focused ? c.text : c.border}`,
        borderRadius: 14, padding: '14px 14px 12px',
        transition: 'border-color 0.15s, box-shadow 0.15s',
        boxShadow: focused ? `0 0 0 4px ${c.primarySoft}` : 'none',
        display: 'flex', alignItems: multiline ? 'flex-start' : 'center', gap: 12,
      }}>
        {leading && (
          <div style={{ color: active ? c.text : c.textTertiary, marginTop: multiline ? 2 : 0, transition: 'color 0.15s' }}>
            {leading}
          </div>
        )}
        <div style={{ flex: 1, minWidth: 0, position: 'relative', paddingTop: 10 }}>
          <label style={{
            position: 'absolute', left: 0, top: active ? -2 : 12,
            fontSize: active ? 10 : 14, fontWeight: active ? 700 : 500,
            color: active ? (focused ? c.text : c.textSecondary) : c.textTertiary,
            letterSpacing: active ? 0.4 : 0, textTransform: active ? 'uppercase' : 'none',
            pointerEvents: 'none', transition: 'all 0.15s',
          }}>
            {label}{optional && <span style={{ fontWeight: 500, opacity: 0.7, textTransform: 'none', letterSpacing: 0 }}> · optional</span>}
          </label>
          {multiline ? (
            <textarea value={value} onChange={e => onChange(e.target.value)}
              onFocus={() => setFocused(true)} onBlur={() => setFocused(false)}
              rows={3} maxLength={maxLen} style={{
                width: '100%', border: 'none', outline: 'none', background: 'none',
                fontSize: 14, fontWeight: 500, color: c.text, fontFamily: 'inherit',
                resize: 'none', padding: 0, lineHeight: 1.45,
              }}/>
          ) : (
            <input value={value} onChange={e => onChange(e.target.value)}
              onFocus={() => setFocused(true)} onBlur={() => setFocused(false)}
              maxLength={maxLen} style={{
                width: '100%', border: 'none', outline: 'none', background: 'none',
                fontSize: 15, fontWeight: 600, color: c.text, fontFamily: 'inherit',
                padding: 0, letterSpacing: -0.1,
              }}/>
          )}
        </div>
        {trailing}
      </div>
      {(hint || maxLen) && (
        <div style={{ display: 'flex', justifyContent: 'space-between',
          padding: '6px 6px 0', fontSize: 11, fontWeight: 500 }}>
          <span style={{ color: c.textTertiary }}>{hint}</span>
          {maxLen && <span style={{ color: c.textTertiary }}>{(value || '').length}/{maxLen}</span>}
        </div>
      )}
    </div>
  );
};

const NEChip = ({ c, active, onClick, icon, children }) => (
  <button onClick={onClick} style={{
    flex: 1, padding: '10px 12px', borderRadius: 12,
    background: active ? c.text : c.surface,
    color: active ? c.surface : c.text,
    border: active ? 'none' : `1px solid ${c.border}`,
    fontSize: 12, fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit',
    display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 6,
  }}>
    <Icon name={icon} size={14}/>
    {children}
  </button>
);

const NewExpense = ({ c, d, close }) => {
  const [title, setTitle] = React.useState('');
  const [amount, setAmount] = React.useState('');
  const [notes, setNotes] = React.useState('');
  const [category, setCategory] = React.useState('food');
  const [receiptMode, setReceiptMode] = React.useState(null); // null | 'gallery' | 'camera' | 'pdf'

  const amountValid = amount && parseFloat(amount) > 0;
  const canSubmit = title.trim() && amountValid;

  const cats = [
    { id: 'food', icon: 'receipt', label: 'Food', color: c.catBills, soft: c.catBillsSoft },
    { id: 'travel', icon: 'sparkle', label: 'Travel', color: c.catGroups, soft: c.catGroupsSoft },
    { id: 'utility', icon: 'bank', label: 'Utility', color: c.catDebts, soft: c.catDebtsSoft },
    { id: 'other', icon: 'wallet', label: 'Other', color: c.accent, soft: c.accentSoft },
  ];

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: c.bg, overflow: 'hidden' }}>
      {/* Header */}
      <div style={{
        background: c.headerGradient, color: '#fff',
        padding: '12px 16px 22px', position: 'relative',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <button onClick={close} style={{ width: 38, height: 38, borderRadius: 11,
            background: 'rgba(255,255,255,0.12)', border: '1px solid rgba(255,255,255,0.15)',
            cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="arrowLeft" size={18} color="#fff"/>
          </button>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 18, fontWeight: 800, letterSpacing: -0.3 }}>New Expense</div>
            <div style={{ fontSize: 12, opacity: 0.7, fontWeight: 500 }}>Submit an expense request</div>
          </div>
          <button style={{ width: 38, height: 38, borderRadius: 11,
            background: c.accent, border: 'none', cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="receipt" size={18} color="#003830"/>
          </button>
        </div>
      </div>

      {/* Amount hero */}
      <div style={{ margin: '-12px 16px 0', position: 'relative', zIndex: 1 }}>
        <div style={{
          background: c.surface, borderRadius: 18, padding: '18px 18px 16px',
          boxShadow: c.shadowLg, border: `1px solid ${c.border}`,
        }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: c.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6 }}>Amount</div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
            <span style={{ fontSize: 22, fontWeight: 700, color: c.textTertiary }}>RM</span>
            <input value={amount} onChange={e => setAmount(e.target.value.replace(/[^0-9.]/g, ''))}
              placeholder="0.00" inputMode="decimal" style={{
              flex: 1, border: 'none', outline: 'none', background: 'none',
              fontSize: 40, fontWeight: 800, color: c.text, fontFamily: 'inherit',
              letterSpacing: -1.2, minWidth: 0, padding: 0,
            }}/>
          </div>
          <div style={{ display: 'flex', gap: 6, marginTop: 10 }}>
            {['10', '25', '50', '100'].map(v => (
              <button key={v} onClick={() => setAmount(v)} style={{
                flex: 1, padding: '7px 0', borderRadius: 9,
                background: c.surfaceAlt, border: `1px solid ${c.border}`,
                fontSize: 12, fontWeight: 700, color: c.text, cursor: 'pointer', fontFamily: 'inherit',
              }}>+{v}</button>
            ))}
          </div>
        </div>
      </div>

      {/* Scrollable form */}
      <div style={{ flex: 1, overflow: 'auto', padding: '16px 16px 24px' }}>
        <NEField c={c} label="Title" value={title} onChange={setTitle}
          leading={<Icon name="edit" size={18}/>}
          hint="What's this expense for?" maxLen={60}/>

        {/* Category */}
        <div style={{ fontSize: 10, fontWeight: 700, color: c.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0.5, margin: '6px 4px 8px' }}>Category</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8, marginBottom: 14 }}>
          {cats.map(cat => (
            <button key={cat.id} onClick={() => setCategory(cat.id)} style={{
              padding: '10px 6px', borderRadius: 12,
              background: category === cat.id ? cat.soft : c.surface,
              border: `1.5px solid ${category === cat.id ? cat.color : c.border}`,
              cursor: 'pointer', fontFamily: 'inherit',
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5,
            }}>
              <Icon name={cat.icon} size={18} color={category === cat.id ? cat.color : c.textSecondary}/>
              <span style={{ fontSize: 11, fontWeight: 700, color: c.text }}>{cat.label}</span>
            </button>
          ))}
        </div>

        <NEField c={c} label="Notes" value={notes} onChange={setNotes}
          leading={<Icon name="menu" size={18}/>}
          multiline optional maxLen={200}/>

        {/* Receipt */}
        <div style={{ fontSize: 10, fontWeight: 700, color: c.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0.5, margin: '14px 4px 8px' }}>Receipt · optional</div>

        {!receiptMode ? (
          <div style={{
            background: c.surface, border: `1.5px dashed ${c.borderStrong}`,
            borderRadius: 14, padding: '20px 14px 14px',
          }}>
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginBottom: 14 }}>
              <div style={{ width: 44, height: 44, borderRadius: 12, background: c.surfaceAlt,
                display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 8 }}>
                <Icon name="upload" size={20} color={c.text}/>
              </div>
              <div style={{ fontSize: 14, fontWeight: 700, color: c.text }}>Attach receipt</div>
              <div style={{ fontSize: 11, color: c.textSecondary, marginTop: 2 }}>Helps approval go faster</div>
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <NEChip c={c} icon="camera" onClick={() => setReceiptMode('camera')}>Camera</NEChip>
              <NEChip c={c} icon="receipt" onClick={() => setReceiptMode('gallery')}>Gallery</NEChip>
              <NEChip c={c} icon="folder" onClick={() => setReceiptMode('pdf')}>PDF</NEChip>
            </div>
          </div>
        ) : (
          <div style={{
            background: c.surface, border: `1px solid ${c.border}`,
            borderRadius: 14, padding: 12, display: 'flex', alignItems: 'center', gap: 12,
          }}>
            <div style={{ width: 52, height: 52, borderRadius: 10, background: c.accentSoft,
              display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <Icon name="checkCircle" size={24} color={c.accentDeep} strokeWidth={2}/>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 13, fontWeight: 700, color: c.text }}>receipt_240512.jpg</div>
              <div style={{ fontSize: 11, color: c.textSecondary }}>284 KB · via {receiptMode}</div>
            </div>
            <button onClick={() => setReceiptMode(null)} style={{ width: 32, height: 32, borderRadius: 8,
              background: c.surfaceAlt, border: 'none', cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="trash" size={16} color={c.danger}/>
            </button>
          </div>
        )}

        <div style={{ height: 100 }}/>
      </div>

      {/* Sticky footer */}
      <div style={{
        background: c.surface, borderTop: `1px solid ${c.border}`,
        padding: '12px 16px 14px', boxShadow: '0 -8px 24px rgba(11,31,58,0.06)',
      }}>
        <button disabled={!canSubmit} onClick={close} style={{
          width: '100%', height: 54, borderRadius: 14,
          background: canSubmit ? c.text : c.surfaceAlt,
          color: canSubmit ? c.surface : c.textTertiary,
          border: 'none', cursor: canSubmit ? 'pointer' : 'not-allowed',
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '0 18px', fontFamily: 'inherit',
        }}>
          <span style={{ fontSize: 13, fontWeight: 600, opacity: 0.7 }}>
            {amountValid ? `RM ${parseFloat(amount).toFixed(2)}` : 'Enter amount'}
          </span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8, fontSize: 15, fontWeight: 800, letterSpacing: -0.2 }}>
            Submit request <Icon name="arrowRight" size={18}/>
          </span>
        </button>
      </div>
    </div>
  );
};

window.NewExpense = NewExpense;
