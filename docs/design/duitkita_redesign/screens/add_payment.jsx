// Add Payment screen — with multi-month support
// User can select 1+ months. Amount auto-calculates (months × monthly due).
// Toggle "Pay multiple months" reveals running total + clear breakdown.

const AddPayment = ({ c, d, close }) => {
  const today = new Date();
  const monthlyDue = 200;
  const monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const fullMonthNames = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  const paidMonths = [0, 1, 2, 3]; // Jan-Apr already paid (current year)

  const [year, setYear] = React.useState(today.getFullYear());
  // selectedMonths: array of { year, month } pairs
  const [selectedMonths, setSelectedMonths] = React.useState([
    { year: today.getFullYear(), month: today.getMonth() },
  ]);
  const [amount, setAmount] = React.useState((monthlyDue).toFixed(2));
  const [amountLocked, setAmountLocked] = React.useState(true); // auto-sync with months
  const [dateChoice, setDateChoice] = React.useState('today');
  const [customDate, setCustomDate] = React.useState(today.toISOString().slice(0, 10));
  const [ref, setRef] = React.useState('');
  const [copied, setCopied] = React.useState(false);

  const account = { bank: 'Maybank', number: '1512 3010 9241', holder: 'NURUL SUHAYDA' };

  // Keep amount synced with month count if locked
  React.useEffect(() => {
    if (amountLocked) {
      setAmount((selectedMonths.length * monthlyDue).toFixed(2));
    }
  }, [selectedMonths.length, amountLocked]);

  const toggleMonth = (y, m) => {
    const isCurrentYear = y === today.getFullYear();
    if (isCurrentYear && paidMonths.includes(m)) return; // can't toggle paid
    const exists = selectedMonths.find(s => s.year === y && s.month === m);
    if (exists) {
      // Don't allow empty selection
      if (selectedMonths.length === 1) return;
      setSelectedMonths(selectedMonths.filter(s => !(s.year === y && s.month === m)));
    } else {
      setSelectedMonths([...selectedMonths, { year: y, month: m }].sort(
        (a, b) => a.year - b.year || a.month - b.month
      ));
    }
  };

  const amountValid = amount && parseFloat(amount) > 0;
  const isCurrentYear = year === today.getFullYear();
  const isMulti = selectedMonths.length > 1;
  const selectionLabel = isMulti
    ? `${selectedMonths.length} months selected`
    : `${fullMonthNames[selectedMonths[0].month]} ${selectedMonths[0].year}`;

  const dateLabel = dateChoice === 'today' ? 'Today, 18 May'
    : dateChoice === 'yesterday' ? 'Yesterday, 17 May'
    : new Date(customDate).toLocaleDateString('en-MY', { day: 'numeric', month: 'short', year: 'numeric' });

  const copyAccount = () => { setCopied(true); setTimeout(() => setCopied(false), 1600); };

  // Quick-select helpers
  const selectMonthsAhead = (n) => {
    const result = [];
    let y = today.getFullYear(), m = today.getMonth();
    while (result.length < n) {
      const isPaid = y === today.getFullYear() && paidMonths.includes(m);
      if (!isPaid) result.push({ year: y, month: m });
      m++;
      if (m > 11) { m = 0; y++; }
    }
    setSelectedMonths(result);
  };

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: c.bg, overflow: 'hidden' }}>
      {/* Header */}
      <div style={{
        background: c.headerGradient, color: '#fff',
        padding: '14px 16px 22px', position: 'relative',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
          <button onClick={close} style={{ width: 38, height: 38, borderRadius: 11,
            background: 'rgba(255,255,255,0.12)', border: '1px solid rgba(255,255,255,0.15)',
            cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="arrowLeft" size={18} color="#fff"/>
          </button>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 16, fontWeight: 800, letterSpacing: -0.2 }}>Add Payment</div>
            <div style={{ fontSize: 11, opacity: 0.65, fontWeight: 500 }}>Hakim Family · monthly contribution</div>
          </div>
        </div>
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          padding: '5px 10px', borderRadius: 999,
          background: 'rgba(30,205,176,0.18)', border: '1px solid rgba(30,205,176,0.3)',
          color: c.accent, fontSize: 11, fontWeight: 700, letterSpacing: 0.1,
        }}>
          <Icon name="sparkle" size={12}/> Auto-approve enabled
        </div>
      </div>

      {/* Bank account card — overlapping pattern (matches New Expense amount card) */}
      <div style={{ margin: '-12px 16px 0', position: 'relative', zIndex: 1 }}>
        <div style={{
          background: c.surface, borderRadius: 18, padding: '18px 18px 16px',
          boxShadow: c.shadowLg, border: `1px solid ${c.border}`,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
            <div style={{
              width: 36, height: 36, borderRadius: 10, background: '#FFCC02',
              display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
            }}>
              <Icon name="bank" size={18} color="#003B6F"/>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 11, fontWeight: 700, color: c.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.5 }}>Pay to</div>
              <div style={{ fontSize: 15, fontWeight: 800, color: c.text, letterSpacing: -0.2 }}>{account.bank}</div>
            </div>
            <button onClick={copyAccount} style={{
              padding: '6px 10px', borderRadius: 9,
              background: copied ? c.successSoft : c.surfaceAlt,
              border: `1px solid ${copied ? c.success : c.border}`,
              cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: 5,
              fontSize: 11, fontWeight: 700, color: copied ? c.success : c.text, fontFamily: 'inherit',
              transition: 'all 0.2s',
            }}>
              <Icon name={copied ? 'check' : 'copy'} size={12}/>
              {copied ? 'Copied' : 'Copy'}
            </button>
          </div>
          <div style={{
            padding: '12px 14px', background: c.surfaceAlt, borderRadius: 10,
            fontFamily: 'Manrope, ui-monospace', fontSize: 20, fontWeight: 800,
            color: c.text, letterSpacing: 1, marginBottom: 10,
          }}>{account.number}</div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <div style={{ fontSize: 10, color: c.textTertiary, fontWeight: 700,
                textTransform: 'uppercase', letterSpacing: 0.4 }}>Account holder</div>
              <div style={{ fontSize: 13, fontWeight: 700, color: c.text, marginTop: 1 }}>{account.holder}</div>
            </div>
            <button style={{
              width: 36, height: 36, borderRadius: 10,
              background: c.accentSoft, border: 'none', cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <Icon name="qr" size={18} color={c.accentDeep}/>
            </button>
          </div>
        </div>
      </div>

      {/* Scrollable content */}
      <div style={{ flex: 1, overflow: 'auto', padding: '16px 16px 24px', position: 'relative' }}>
        {/* Section: Which months */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          margin: '0 4px 8px' }}>
          <div style={{ fontSize: 10, fontWeight: 700, color: c.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.5 }}>
            Pay for {isMulti ? `${selectedMonths.length} months` : 'which month'}
          </div>
          {isMulti && (
            <button onClick={() => setSelectedMonths([selectedMonths[0]])} style={{
              fontSize: 11, fontWeight: 700, color: c.textSecondary,
              background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'inherit',
              display: 'inline-flex', alignItems: 'center', gap: 4,
            }}><Icon name="close" size={11}/> Clear</button>
          )}
        </div>
        <div style={{
          background: c.surface, border: `1px solid ${c.border}`,
          borderRadius: 16, padding: 14, marginBottom: 12,
        }}>
          {/* Year stepper */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            marginBottom: 12 }}>
            <button onClick={() => setYear(year - 1)} style={{
              width: 32, height: 32, borderRadius: 10, background: c.surfaceAlt,
              border: `1px solid ${c.border}`, cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <Icon name="chevronLeft" size={14} color={c.text}/>
            </button>
            <div style={{ fontSize: 17, fontWeight: 800, color: c.text, letterSpacing: -0.2 }}>
              {year}
              {isCurrentYear && (
                <span style={{ marginLeft: 8, fontSize: 10, fontWeight: 700, color: c.accentDeep,
                  background: c.accentSoft, padding: '2px 7px', borderRadius: 6,
                  verticalAlign: 'middle', textTransform: 'uppercase', letterSpacing: 0.4 }}>Current</span>
              )}
            </div>
            <button onClick={() => setYear(year + 1)} style={{
              width: 32, height: 32, borderRadius: 10, background: c.surfaceAlt,
              border: `1px solid ${c.border}`, cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <Icon name="chevronRight" size={14} color={c.text}/>
            </button>
          </div>

          {/* Month grid */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 6 }}>
            {monthNames.map((m, i) => {
              const paid = year === today.getFullYear() && paidMonths.includes(i);
              const selected = selectedMonths.some(s => s.year === year && s.month === i);
              const future = year > today.getFullYear() || (isCurrentYear && i > today.getMonth());
              const selectionIndex = selectedMonths.findIndex(s => s.year === year && s.month === i);
              return (
                <button key={m} disabled={paid} onClick={() => toggleMonth(year, i)} style={{
                  position: 'relative',
                  padding: '11px 0', borderRadius: 10,
                  background: selected ? c.text : paid ? c.successSoft : c.surface,
                  color: selected ? c.surface : paid ? c.success : future ? c.textTertiary : c.text,
                  border: selected ? 'none' : `1px solid ${paid ? c.successSoft : c.border}`,
                  fontSize: 13, fontWeight: 700, cursor: paid ? 'default' : 'pointer',
                  fontFamily: 'inherit', transition: 'all 0.15s',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4,
                }}>
                  {paid && <Icon name="check" size={11} color={c.success} strokeWidth={3}/>}
                  {selected && (
                    <span style={{
                      position: 'absolute', top: 4, right: 5,
                      minWidth: 14, height: 14, borderRadius: 7,
                      background: c.accent, color: '#003830',
                      fontSize: 9, fontWeight: 800,
                      display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '0 3px',
                    }}>{selectionIndex + 1}</span>
                  )}
                  {m}
                </button>
              );
            })}
          </div>

          {/* Legend + quick selects */}
          <div style={{ display: 'flex', gap: 14, marginTop: 12, paddingTop: 12,
            borderTop: `1px solid ${c.border}`, fontSize: 10, fontWeight: 600,
            color: c.textSecondary }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
              <span style={{ width: 8, height: 8, borderRadius: 3, background: c.text }}/>Selected
            </span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
              <span style={{ width: 8, height: 8, borderRadius: 3, background: c.successSoft,
                border: `1px solid ${c.success}` }}/>Paid
            </span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
              <span style={{ width: 8, height: 8, borderRadius: 3, border: `1px solid ${c.borderStrong}` }}/>Open
            </span>
          </div>
        </div>

        {/* Quick: pay multiple months */}
        <div style={{ display: 'flex', gap: 6, marginBottom: 16, overflowX: 'auto' }}>
          {[
            { n: 1, label: 'This month' },
            { n: 3, label: '3 months' },
            { n: 6, label: '6 months' },
            { n: 12, label: '12 months' },
          ].map(opt => {
            const active = selectedMonths.length === opt.n;
            return (
              <button key={opt.n} onClick={() => selectMonthsAhead(opt.n)} style={{
                flex: 1, minWidth: 0, padding: '9px 6px', borderRadius: 10,
                background: active ? c.accentSoft : c.surface,
                border: `1px solid ${active ? c.accent : c.border}`,
                color: active ? c.accentDeep : c.text,
                fontSize: 11, fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit',
                whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
              }}>{opt.label}</button>
            );
          })}
        </div>

        {/* Selection breakdown card (only shown when multi) */}
        {isMulti && (
          <div style={{
            background: c.surface, border: `1px solid ${c.accent}`,
            borderRadius: 16, padding: 14, marginBottom: 16,
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
              <div style={{ fontSize: 12, fontWeight: 700, color: c.text }}>
                Paying for {selectedMonths.length} months
              </div>
              <Pill c={c} bg={c.accentSoft} color={c.accentDeep}>
                {selectedMonths.length} × RM {monthlyDue}
              </Pill>
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {selectedMonths.map((s, i) => (
                <div key={i} style={{
                  display: 'inline-flex', alignItems: 'center', gap: 5,
                  padding: '5px 9px 5px 7px', borderRadius: 999,
                  background: c.surfaceAlt, fontSize: 11, fontWeight: 700, color: c.text,
                }}>
                  <span style={{ width: 16, height: 16, borderRadius: 8,
                    background: c.text, color: c.surface, fontSize: 9, fontWeight: 800,
                    display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>{i + 1}</span>
                  {monthNames[s.month]} {String(s.year).slice(2)}
                  {selectedMonths.length > 1 && (
                    <button onClick={() => toggleMonth(s.year, s.month)} style={{
                      width: 14, height: 14, borderRadius: 7,
                      background: c.borderStrong, border: 'none', cursor: 'pointer',
                      display: 'inline-flex', alignItems: 'center', justifyContent: 'center', padding: 0,
                      marginLeft: 2,
                    }}>
                      <Icon name="close" size={9} color={c.surface} strokeWidth={3}/>
                    </button>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Section: Amount */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          margin: '0 4px 8px' }}>
          <div style={{ fontSize: 10, fontWeight: 700, color: c.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.5 }}>Amount</div>
          {isMulti && (
            <button onClick={() => setAmountLocked(!amountLocked)} style={{
              fontSize: 11, fontWeight: 700, color: amountLocked ? c.accentDeep : c.textSecondary,
              background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'inherit',
              display: 'inline-flex', alignItems: 'center', gap: 4,
            }}>
              <Icon name={amountLocked ? 'lock' : 'edit'} size={11}/>
              {amountLocked ? 'Auto-calculated' : 'Editing'}
            </button>
          )}
        </div>
        <div style={{
          background: c.surface, border: `1px solid ${c.border}`,
          borderRadius: 16, padding: 16, marginBottom: 16,
        }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
            <span style={{ fontSize: 20, fontWeight: 700, color: c.textTertiary }}>RM</span>
            <input value={amount} onChange={e => {
              setAmountLocked(false);
              setAmount(e.target.value.replace(/[^0-9.]/g, ''));
            }} placeholder="0.00" inputMode="decimal" style={{
              flex: 1, border: 'none', outline: 'none', background: 'none',
              fontSize: 36, fontWeight: 800, color: c.text, fontFamily: 'inherit',
              letterSpacing: -1.2, minWidth: 0, padding: 0,
            }}/>
          </div>
          {isMulti && amountLocked && (
            <div style={{ marginTop: 6, fontSize: 11, color: c.textSecondary, fontWeight: 600 }}>
              {selectedMonths.length} months × RM {monthlyDue}.00
            </div>
          )}
          {!isMulti && (
            <div style={{ display: 'flex', gap: 6, marginTop: 12 }}>
              <AmountChip c={c} label={`Full · RM ${monthlyDue}`}
                active={parseFloat(amount) === monthlyDue}
                onClick={() => { setAmountLocked(true); setAmount(monthlyDue.toFixed(2)); }}/>
              <AmountChip c={c} label={`Half · RM ${monthlyDue / 2}`}
                active={parseFloat(amount) === monthlyDue / 2}
                onClick={() => { setAmountLocked(false); setAmount((monthlyDue / 2).toFixed(2)); }}/>
              <AmountChip c={c} label="Custom"
                active={parseFloat(amount) !== monthlyDue && parseFloat(amount) !== monthlyDue / 2 && amountValid}/>
            </div>
          )}
          {!isMulti && amountValid && parseFloat(amount) < monthlyDue && (
            <div style={{ marginTop: 12, padding: 10, borderRadius: 10,
              background: c.warningSoft, display: 'flex', gap: 8, alignItems: 'flex-start' }}>
              <Icon name="info" size={14} color={c.warning} strokeWidth={2}/>
              <div style={{ fontSize: 12, color: c.text, fontWeight: 500, lineHeight: 1.4 }}>
                Partial payment. <span style={{ fontWeight: 700 }}>RM {(monthlyDue - parseFloat(amount)).toFixed(2)}</span> will remain for {monthNames[selectedMonths[0].month]} {selectedMonths[0].year}.
              </div>
            </div>
          )}
          {isMulti && amountValid && Math.abs(parseFloat(amount) - selectedMonths.length * monthlyDue) > 0.01 && (
            <div style={{ marginTop: 12, padding: 10, borderRadius: 10,
              background: c.warningSoft, display: 'flex', gap: 8, alignItems: 'flex-start' }}>
              <Icon name="info" size={14} color={c.warning} strokeWidth={2}/>
              <div style={{ fontSize: 12, color: c.text, fontWeight: 500, lineHeight: 1.4 }}>
                Amount doesn't match {selectedMonths.length} × RM {monthlyDue} = <span style={{ fontWeight: 700 }}>RM {(selectedMonths.length * monthlyDue).toFixed(2)}</span>.
                Admin will split the payment proportionally.
              </div>
            </div>
          )}
        </div>

        {/* Section: Date */}
        <SectionLabel c={c}>Payment date</SectionLabel>
        <div style={{
          background: c.surface, border: `1px solid ${c.border}`,
          borderRadius: 16, padding: 14, marginBottom: 16,
        }}>
          <div style={{ display: 'flex', gap: 6, marginBottom: dateChoice === 'custom' ? 12 : 0 }}>
            {[
              { id: 'today', label: 'Today' },
              { id: 'yesterday', label: 'Yesterday' },
              { id: 'custom', label: 'Pick date' },
            ].map(o => (
              <button key={o.id} onClick={() => setDateChoice(o.id)} style={{
                flex: 1, padding: '10px 8px', borderRadius: 10,
                background: dateChoice === o.id ? c.text : c.surface,
                color: dateChoice === o.id ? c.surface : c.text,
                border: dateChoice === o.id ? 'none' : `1px solid ${c.border}`,
                fontSize: 12, fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit',
                display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              }}>
                {dateChoice === o.id && <Icon name="check" size={12} strokeWidth={3}/>}
                {o.label}
              </button>
            ))}
          </div>
          {dateChoice === 'custom' && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 10,
              padding: '12px 12px', background: c.surfaceAlt, borderRadius: 10 }}>
              <Icon name="calendar" size={18} color={c.text}/>
              <input type="date" value={customDate} onChange={e => setCustomDate(e.target.value)}
                style={{
                  flex: 1, border: 'none', outline: 'none', background: 'none',
                  fontSize: 14, fontWeight: 700, color: c.text, fontFamily: 'inherit',
                }}/>
            </div>
          )}
        </div>

        {/* Reference */}
        <SectionLabel c={c}>Reference <span style={{ fontWeight: 500, opacity: 0.7, textTransform: 'none', letterSpacing: 0 }}>· optional</span></SectionLabel>
        <div style={{
          background: c.surface, border: `1px solid ${c.border}`,
          borderRadius: 16, padding: '4px 14px', marginBottom: 16,
          display: 'flex', alignItems: 'center', gap: 10,
        }}>
          <Icon name="receipt" size={18} color={c.textTertiary}/>
          <input value={ref} onChange={e => setRef(e.target.value)}
            placeholder="Bank transaction ID, e.g. MB240518…" style={{
              flex: 1, border: 'none', outline: 'none', background: 'none',
              fontSize: 14, fontWeight: 500, color: c.text, fontFamily: 'inherit',
              padding: '14px 0',
            }}/>
        </div>

        <div style={{ height: 80 }}/>
      </div>

      {/* Sticky footer */}
      <div style={{
        background: c.surface, borderTop: `1px solid ${c.border}`,
        padding: '12px 16px 14px',
        boxShadow: '0 -8px 24px rgba(11,31,58,0.06)',
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between',
          padding: '0 4px 10px', fontSize: 12 }}>
          <span style={{ color: c.textSecondary, fontWeight: 600 }}>{selectionLabel} · {dateLabel}</span>
          <span style={{ color: c.text, fontWeight: 800 }}>
            RM {amountValid ? parseFloat(amount).toFixed(2) : '0.00'}
          </span>
        </div>
        <button disabled={!amountValid} onClick={close} style={{
          width: '100%', height: 54, borderRadius: 14,
          background: amountValid ? c.accent : c.surfaceAlt,
          color: amountValid ? '#003830' : c.textTertiary,
          border: 'none', cursor: amountValid ? 'pointer' : 'not-allowed',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
          fontSize: 15, fontWeight: 800, letterSpacing: -0.2, fontFamily: 'inherit',
          boxShadow: amountValid ? `0 8px 20px ${c.accent}50` : 'none',
        }}>
          <Icon name="checkCircle" size={18}/>
          Submit payment {isMulti && `· ${selectedMonths.length} months`}
        </button>
      </div>
    </div>
  );
};

const SectionLabel = ({ c, children }) => (
  <div style={{ fontSize: 10, fontWeight: 700, color: c.textSecondary,
    textTransform: 'uppercase', letterSpacing: 0.5, margin: '0 4px 8px' }}>
    {children}
  </div>
);

const AmountChip = ({ c, label, active, onClick }) => (
  <button onClick={onClick} style={{
    flex: 1, padding: '8px 6px', borderRadius: 9,
    background: active ? c.accentSoft : c.surfaceAlt,
    border: `1px solid ${active ? c.accent : c.border}`,
    color: active ? c.accentDeep : c.textSecondary,
    fontSize: 11, fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit',
    whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
  }}>{label}</button>
);

window.AddPayment = AddPayment;
