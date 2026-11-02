// Shared base for DuitKita home redesign explorations
// Light theme only. Tokens lifted from theme.jsx.

const C = {
  bg: '#F2F4F7', surface: '#FFFFFF', surfaceAlt: '#F7F9FB',
  border: '#E6EAF0', borderStrong: '#D1D7E0',
  text: '#0B1F3A', textSecondary: '#5B6B82', textTertiary: '#8B97AA',
  primary: '#0B1F3A', primarySoft: '#E8ECF3',
  accent: '#00C2A8', accentSoft: '#E0F7F2', accentDeep: '#008C7A',
  success: '#10B981', successSoft: '#E5F7EF',
  warning: '#F59E0B', warningSoft: '#FEF3DC',
  danger: '#EF4444', dangerSoft: '#FDECEC',
  info: '#3B82F6', infoSoft: '#E8F0FE',
  catGroups: '#5B6FFF', catGroupsSoft: '#ECEFFF',
  catDebts: '#3B82F6', catDebtsSoft: '#E8F0FE',
  catBills: '#F59E0B', catBillsSoft: '#FEF3DC',
  headerGradient: 'linear-gradient(155deg, #0B1F3A 0%, #12294E 100%)',
  shadow: '0 1px 2px rgba(11,31,58,0.04), 0 6px 16px rgba(11,31,58,0.05)',
  shadowLg: '0 18px 40px rgba(11,31,58,0.14)',
};

const fmt = (n, dec = 2) => {
  const v = Math.abs(n).toLocaleString('en-MY', { minimumFractionDigits: dec, maximumFractionDigits: dec });
  return (n < 0 ? '-' : '') + v;
};
const rm = (n, dec = 2) => 'RM ' + fmt(n, dec);

// ── Shared mock data (one source of truth across variations) ──
const D = {
  user: { name: 'Aiman Hakim', first: 'Aiman' },
  groups: [
    { id: 'g1', name: 'Hakim Family', desc: 'Monthly to mum', members: 5, paid: 5, monthly: 500, emoji: '🏠', status: 'confirmed' },
    { id: 'g3', name: 'Office Lunch Pool', desc: 'Weekly food kitty', members: 8, paid: 5, monthly: 80, emoji: '🍱', status: 'confirmed' },
    { id: 'g2', name: 'KL Trip 2026', desc: 'Squad getaway', members: 6, paid: 0, monthly: 0, emoji: '✈️', status: 'oneoff' },
  ],
  upNext: [
    { id: 'b2', kind: 'bill', title: 'Astro Sports Pack', sub: 'Bill · due in 12 days', amount: 89.90, cat: 'catBills', icon: 'receipt' },
    { id: 'd1', kind: 'loan', title: 'Toyota Vios', sub: 'Loan · due 28 May', amount: 1280, cat: 'catDebts', icon: 'bank' },
    { id: 'b3', kind: 'bill', title: 'Spotify Family', sub: 'Bill · due 28th', amount: 24.90, cat: 'catBills', icon: 'receipt' },
  ],
};
// Totals
D.groupMonthly = 580; D.loanMonthly = 1600; D.billMonthly = 253.80;
D.total = D.groupMonthly + D.loanMonthly + D.billMonthly; // 2433.80
D.paid = 1039; D.remaining = D.total - D.paid; D.pct = Math.round((D.paid / D.total) * 100);

// ── Icon set ──
const Icon = ({ name, size = 20, color = 'currentColor', sw = 1.8 }) => {
  const p = {
    home: <path d="M3 10.5L12 3l9 7.5V20a1 1 0 01-1 1h-5v-7h-6v7H4a1 1 0 01-1-1v-9.5z"/>,
    users: <><circle cx="9" cy="8" r="3.2"/><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6"/><circle cx="17" cy="9" r="2.5"/><path d="M15 14c2.5 0 6 1.7 6 5"/></>,
    bank: <><path d="M3 10l9-5 9 5"/><path d="M5 10v8M9 10v8M15 10v8M19 10v8"/><path d="M3 21h18"/></>,
    receipt: <><path d="M5 3h14v18l-3-2-3 2-3-2-3 2-2-1.5V3z"/><path d="M8 8h8M8 12h8M8 16h5"/></>,
    bell: <><path d="M6 8a6 6 0 1112 0v5l1.5 3h-15L6 13V8z"/><path d="M9 19a3 3 0 006 0"/></>,
    help: <><circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 015 0c0 1.5-2.5 2-2.5 4"/><circle cx="12" cy="17" r="0.4" fill="currentColor"/></>,
    plus: <path d="M12 5v14M5 12h14"/>,
    plusBold: <path d="M12 4v16M4 12h16" strokeWidth="2.4"/>,
    qr: <><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3M21 14v3M14 18v3h3M21 21h-3"/></>,
    pie: <><path d="M21 12A9 9 0 113 12 9 9 0 0121 12z"/><path d="M12 3v9l8 4"/></>,
    trending: <><path d="M3 17l6-6 4 4 8-8"/><path d="M14 7h7v7"/></>,
    chevronRight: <path d="M9 6l6 6-6 6"/>,
    arrowRight: <><path d="M5 12h14M13 6l6 6-6 6"/></>,
    arrowUpRight: <><path d="M7 17L17 7M8 7h9v9"/></>,
    check: <path d="M5 12l5 5L20 7"/>,
    user: <><circle cx="12" cy="8" r="3.5"/><path d="M5 21c0-4 3-7 7-7s7 3 7 7"/></>,
    sparkle: <><path d="M12 3l1.7 4.5L18 9l-4.3 1.5L12 15l-1.7-4.5L6 9l4.3-1.5L12 3z"/></>,
    wallet: <><path d="M3 7a2 2 0 012-2h12l4 4v10a2 2 0 01-2 2H5a2 2 0 01-2-2V7z"/><path d="M16 13h2"/></>,
    clock: <><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></>,
    dot: <circle cx="12" cy="12" r="3" fill="currentColor"/>,
  };
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" style={{ flexShrink: 0 }}>{p[name] || p.dot}</svg>;
};

const AV_PALETTE = [['#5B6FFF','#ECEFFF'],['#00C2A8','#E0F7F2'],['#F59E0B','#FEF3DC'],['#EF4444','#FDECEC'],['#3B82F6','#E8F0FE'],['#8B5CF6','#F1EBFE'],['#10B981','#E5F7EF'],['#EC4899','#FCE7F3']];
const Avatar = ({ name, size = 40 }) => {
  const initials = (name || '?').split(' ').slice(0, 2).map(s => s[0]).join('').toUpperCase();
  let h = 0; for (const ch of (name || '')) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  const [fg, bg] = AV_PALETTE[h % AV_PALETTE.length];
  return <div style={{ width: size, height: size, borderRadius: '50%', background: bg, color: fg, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: size * 0.4, fontWeight: 700, letterSpacing: -0.3, flexShrink: 0 }}>{initials}</div>;
};

// ── Phone chrome ──
const StatusBar = ({ dark }) => (
  <div style={{ height: 44, padding: '0 22px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: 14, fontWeight: 700, color: dark ? '#fff' : C.text, flexShrink: 0 }}>
    <span>9:41</span>
    <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
      <svg width="17" height="11" viewBox="0 0 17 11"><path d="M0 8h2v3H0zM4.5 5.5h2v5.5h-2zM9 3h2v8H9zM13.5 0h2v11h-2z" fill={dark ? '#fff' : C.text}/></svg>
      <svg width="24" height="12" viewBox="0 0 24 12"><rect x="1" y="1" width="19" height="10" rx="2.5" stroke={dark ? '#fff' : C.text} strokeOpacity="0.5" fill="none"/><rect x="3" y="3" width="14" height="6" rx="1" fill={dark ? '#fff' : C.text}/><rect x="21.5" y="4" width="2" height="4" rx="1" fill={dark ? '#fff' : C.text}/></svg>
    </div>
  </div>
);

const BottomNav = () => {
  const items = [
    { icon: 'home', label: 'Home', active: true },
    { icon: 'users', label: 'Groups' },
    { special: true },
    { icon: 'bank', label: 'Debts' },
    { icon: 'user', label: 'Profile' },
  ];
  return (
    <div style={{ background: C.surface, borderTop: `1px solid ${C.border}`, padding: '8px 10px 6px', display: 'flex', alignItems: 'center', justifyContent: 'space-around', flexShrink: 0 }}>
      {items.map((it, i) => it.special ? (
        <button key={i} style={{ width: 54, height: 54, borderRadius: 19, background: C.text, border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 8px 18px rgba(11,31,58,0.28)', marginTop: -18 }}>
          <Icon name="plus" size={24} color="#fff" sw={2.4}/>
        </button>
      ) : (
        <button key={i} style={{ background: 'none', border: 'none', cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, padding: '4px 12px', color: it.active ? C.text : C.textTertiary, fontFamily: 'inherit' }}>
          <Icon name={it.icon} size={23} sw={it.active ? 2.2 : 1.7}/>
          <span style={{ fontSize: 10, fontWeight: it.active ? 700 : 500 }}>{it.label}</span>
        </button>
      ))}
    </div>
  );
};

const HomeIndicator = () => (
  <div style={{ height: 26, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, background: C.surface }}>
    <div style={{ width: 132, height: 5, borderRadius: 3, background: C.text, opacity: 0.22 }}/>
  </div>
);

// Greeting header shared across variations
const Greeting = ({ onDark }) => (
  <div style={{ padding: '6px 20px 4px', display: 'flex', alignItems: 'center', gap: 12 }}>
    <Avatar name={D.user.name} size={44}/>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 13, color: C.textSecondary, fontWeight: 500 }}>Selamat petang,</div>
      <div style={{ fontSize: 18, fontWeight: 800, color: C.text, letterSpacing: -0.3 }}>{D.user.first}</div>
    </div>
    {['help', 'bell'].map(n => (
      <button key={n} style={{ width: 42, height: 42, borderRadius: 13, background: C.surface, border: `1px solid ${C.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', position: 'relative' }}>
        <Icon name={n} size={20} color={C.text}/>
        {n === 'bell' && <span style={{ position: 'absolute', top: 9, right: 10, width: 8, height: 8, borderRadius: 4, background: C.danger, border: `2px solid ${C.surface}` }}/>}
      </button>
    ))}
  </div>
);

// Section label
const SecHead = ({ title, action, style }) => (
  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12, ...style }}>
    <div style={{ fontSize: 12.5, fontWeight: 700, letterSpacing: 0.5, textTransform: 'uppercase', color: C.textSecondary }}>{title}</div>
    {action}
  </div>
);

// Device shell — renders a labelled phone with content
const Phone = ({ label, tag, children }) => (
  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 0 }}>
    <div style={{ textAlign: 'center', marginBottom: 18 }}>
      <div style={{ fontSize: 20, fontWeight: 800, color: '#0B1F3A', letterSpacing: -0.4 }}>{label}</div>
      <div style={{ fontSize: 13, color: '#5B6B82', marginTop: 3, maxWidth: 300 }}>{tag}</div>
    </div>
    <div style={{ width: 402, height: 858, borderRadius: 46, background: C.bg, position: 'relative', overflow: 'hidden', border: '9px solid #10151F', boxShadow: '0 40px 90px rgba(11,25,50,0.30), 0 0 0 1.5px rgba(255,255,255,0.04) inset' }}>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column' }}>
        {children}
      </div>
    </div>
  </div>
);

// Scroll region helper
const Scroll = ({ children, dark }) => (
  <div style={{ flex: 1, overflow: 'auto', background: dark ? C.text : C.bg }}>{children}</div>
);

Object.assign(window, { C, fmt, rm, D, Icon, Avatar, StatusBar, BottomNav, HomeIndicator, Greeting, SecHead, Phone, Scroll });
