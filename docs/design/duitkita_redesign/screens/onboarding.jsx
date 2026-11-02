// Onboarding carousel — 4 slides, dismissible

const ONBOARD_SLIDES = [
  {
    title: 'Track money\nwith your people',
    body: 'Split bills with family, settle group expenses, and stop chasing cousins for that RM50.',
    icon: 'users',
    accent: 'catGroups',
    art: 'people',
  },
  {
    title: 'Never miss\na monthly payment',
    body: 'See every loan, bill and group contribution in one place. We\'ll nudge you before due dates.',
    icon: 'calendar',
    accent: 'accent',
    art: 'calendar',
  },
  {
    title: 'Pay & verify\nin two taps',
    body: 'Generate a DuitNow QR, snap a receipt, and the admin gets a clean approve / reject card.',
    icon: 'qr',
    accent: 'catBills',
    art: 'qr',
  },
  {
    title: 'Stay in control,\ntogether',
    body: 'Members see what they owe. Admins see who paid. No spreadsheets, no awkward chats.',
    icon: 'sparkle',
    accent: 'catDebts',
    art: 'shield',
  },
];

const OnboardArt = ({ kind, c }) => {
  if (kind === 'people') return (
    <div style={{ position: 'relative', width: 240, height: 200 }}>
      <div style={{ position: 'absolute', inset: 0, borderRadius: 24, background: c.catGroupsSoft }}/>
      <div style={{ position: 'absolute', left: 30, top: 40, width: 100, height: 130, borderRadius: 16, background: c.surface, border: `1px solid ${c.border}`, boxShadow: c.shadow, padding: 12 }}>
        <Avatar name="Mum" size={32}/>
        <div style={{ marginTop: 10, height: 6, borderRadius: 3, background: c.surfaceAlt }}/>
        <div style={{ marginTop: 6, height: 6, borderRadius: 3, background: c.surfaceAlt, width: '60%' }}/>
        <div style={{ marginTop: 16, fontSize: 18, fontWeight: 800, color: c.catGroups, letterSpacing: -0.4 }}>RM 240</div>
        <div style={{ fontSize: 10, color: c.textTertiary, fontWeight: 500 }}>this month</div>
      </div>
      <div style={{ position: 'absolute', right: 24, top: 22, width: 100, height: 130, borderRadius: 16, background: c.surface, border: `1px solid ${c.border}`, boxShadow: c.shadow, padding: 12, transform: 'rotate(4deg)' }}>
        <Avatar name="Adik Aliya" size={32}/>
        <div style={{ marginTop: 10, height: 6, borderRadius: 3, background: c.surfaceAlt }}/>
        <div style={{ marginTop: 6, height: 6, borderRadius: 3, background: c.surfaceAlt, width: '70%' }}/>
        <div style={{ marginTop: 16, fontSize: 18, fontWeight: 800, color: c.accent, letterSpacing: -0.4 }}>RM 80</div>
        <div style={{ fontSize: 10, color: c.textTertiary, fontWeight: 500 }}>this month</div>
      </div>
      <div style={{ position: 'absolute', left: '50%', bottom: -10, transform: 'translateX(-50%)', padding: '8px 14px', borderRadius: 999, background: c.text, color: c.surface, fontSize: 12, fontWeight: 700, boxShadow: c.shadowLg }}>
        Family · 4 members
      </div>
    </div>
  );
  if (kind === 'calendar') return (
    <div style={{ position: 'relative', width: 240, height: 200 }}>
      <div style={{ position: 'absolute', inset: 0, borderRadius: 24, background: c.accentSoft }}/>
      <div style={{ position: 'absolute', left: 24, top: 28, right: 24, bottom: 28, borderRadius: 18, background: c.surface, border: `1px solid ${c.border}`, padding: 14, boxShadow: c.shadow }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
          <div style={{ fontSize: 13, fontWeight: 700, color: c.text }}>May 2026</div>
          <div style={{ fontSize: 10, fontWeight: 600, color: c.accent, padding: '2px 8px', borderRadius: 8, background: c.accentSoft }}>3 due</div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 4 }}>
          {Array.from({ length: 21 }).map((_, i) => {
            const isDue = [4, 9, 17].includes(i);
            const isToday = i === 12;
            return (
              <div key={i} style={{
                aspectRatio: '1', borderRadius: 6, fontSize: 9, fontWeight: 600,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                background: isToday ? c.text : isDue ? c.accent : c.surfaceAlt,
                color: isToday || isDue ? c.surface : c.textTertiary,
              }}>{i + 1}</div>
            );
          })}
        </div>
      </div>
    </div>
  );
  if (kind === 'qr') return (
    <div style={{ position: 'relative', width: 240, height: 200 }}>
      <div style={{ position: 'absolute', inset: 0, borderRadius: 24, background: c.catBillsSoft }}/>
      <div style={{ position: 'absolute', left: '50%', top: 18, transform: 'translateX(-50%)', width: 130, height: 160, borderRadius: 16, background: c.surface, border: `1px solid ${c.border}`, boxShadow: c.shadow, padding: 14 }}>
        <div style={{ width: '100%', aspectRatio: '1', background: c.text, borderRadius: 8, padding: 8 }}>
          <div style={{ width: '100%', height: '100%', background:
            `repeating-linear-gradient(0deg, ${c.surface} 0 4px, transparent 4px 8px),
             repeating-linear-gradient(90deg, ${c.surface} 0 4px, transparent 4px 8px)`,
            borderRadius: 4,
          }}/>
        </div>
        <div style={{ marginTop: 10, fontSize: 10, fontWeight: 700, color: c.text, textAlign: 'center' }}>RM 120.00</div>
        <div style={{ fontSize: 9, color: c.textTertiary, textAlign: 'center' }}>DuitNow QR</div>
      </div>
    </div>
  );
  return (
    <div style={{ position: 'relative', width: 240, height: 200 }}>
      <div style={{ position: 'absolute', inset: 0, borderRadius: 24, background: c.catDebtsSoft }}/>
      <div style={{ position: 'absolute', left: '50%', top: '50%', transform: 'translate(-50%, -50%)' }}>
        <div style={{ width: 120, height: 120, borderRadius: 24, background: c.surface, border: `1px solid ${c.border}`, boxShadow: c.shadow, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="checkCircle" size={56} color={c.catDebts} strokeWidth={1.6}/>
        </div>
      </div>
    </div>
  );
};

const Onboarding = ({ c, d, onDone }) => {
  const [i, setI] = React.useState(0);
  const slide = ONBOARD_SLIDES[i];
  const isLast = i === ONBOARD_SLIDES.length - 1;
  return (
    <div style={{
      flex: 1, display: 'flex', flexDirection: 'column',
      background: c.bg, padding: '12px 24px 24px',
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <div style={{ width: 28, height: 28, borderRadius: 8,
            background: `linear-gradient(135deg, ${c.primary}, ${c.accent})`,
            display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="wallet" size={16} color="#fff"/>
          </div>
          <span style={{ fontSize: 16, fontWeight: 800, color: c.text, letterSpacing: -0.3 }}>DuitKita</span>
        </div>
        {!isLast && (
          <button onClick={onDone} style={{
            background: 'none', border: 'none', color: c.textSecondary,
            fontSize: 14, fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit', padding: 8,
          }}>Skip</button>
        )}
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '20px 0' }}>
        <OnboardArt kind={slide.art} c={c}/>
        <div style={{ marginTop: 36, textAlign: 'center', whiteSpace: 'pre-line' }}>
          <h1 style={{ fontSize: 28, fontWeight: 800, color: c.text, letterSpacing: -0.6, margin: 0, lineHeight: 1.15 }}>
            {slide.title}
          </h1>
          <p style={{ fontSize: 15, color: c.textSecondary, lineHeight: 1.5, margin: '14px auto 0', maxWidth: 280 }}>
            {slide.body}
          </p>
        </div>
      </div>

      <div style={{ display: 'flex', justifyContent: 'center', gap: 6, marginBottom: 20 }}>
        {ONBOARD_SLIDES.map((_, idx) => (
          <div key={idx} style={{
            height: 6, borderRadius: 3, transition: 'all 0.3s',
            width: idx === i ? 24 : 6,
            background: idx === i ? c.text : c.borderStrong,
          }}/>
        ))}
      </div>

      <Button c={c} full size="lg" onClick={() => isLast ? onDone() : setI(i + 1)}
        trailing={<Icon name="arrowRight" size={18}/>}>
        {isLast ? 'Get started' : 'Continue'}
      </Button>
    </div>
  );
};

window.Onboarding = Onboarding;
