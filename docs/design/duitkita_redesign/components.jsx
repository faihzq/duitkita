// Shared UI primitives for DuitKita prototype

const Icon = ({ name, size = 20, color = 'currentColor', strokeWidth = 1.8 }) => {
  const paths = {
    home: <><path d="M3 10.5L12 3l9 7.5V20a1 1 0 01-1 1h-5v-7h-6v7H4a1 1 0 01-1-1v-9.5z"/></>,
    homeFilled: <><path d="M3 10.5L12 3l9 7.5V20a1 1 0 01-1 1h-5v-7h-6v7H4a1 1 0 01-1-1v-9.5z" fill="currentColor"/></>,
    users: <><circle cx="9" cy="8" r="3.2"/><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6"/><circle cx="17" cy="9" r="2.5"/><path d="M15 14c2.5 0 6 1.7 6 5"/></>,
    bank: <><path d="M3 10l9-5 9 5"/><path d="M5 10v8M9 10v8M15 10v8M19 10v8"/><path d="M3 21h18"/></>,
    soccer: <><circle cx="12" cy="12" r="9"/><path d="M12 3v6m0 6v6M3 12h6m6 0h6M7 7l4 3m2 0l4-3M7 17l4-3m2 0l4 3"/></>,
    bell: <><path d="M6 8a6 6 0 1112 0v5l1.5 3h-15L6 13V8z"/><path d="M9 19a3 3 0 006 0"/></>,
    plus: <><path d="M12 5v14M5 12h14"/></>,
    plusBold: <><path d="M12 4v16M4 12h16" strokeWidth={2.4}/></>,
    chevronRight: <><path d="M9 6l6 6-6 6"/></>,
    chevronLeft: <><path d="M15 6l-6 6 6 6"/></>,
    chevronDown: <><path d="M6 9l6 6 6-6"/></>,
    arrowRight: <><path d="M5 12h14M13 6l6 6-6 6"/></>,
    arrowLeft: <><path d="M19 12H5M11 6l-6 6 6 6"/></>,
    check: <><path d="M5 12l5 5L20 7"/></>,
    checkCircle: <><circle cx="12" cy="12" r="9"/><path d="M8 12.5l3 3 5-6"/></>,
    close: <><path d="M6 6l12 12M18 6L6 18"/></>,
    settings: <><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 00.3 1.8l.1.1a2 2 0 11-2.8 2.8l-.1-.1a1.7 1.7 0 00-1.8-.3 1.7 1.7 0 00-1 1.5V21a2 2 0 11-4 0v-.1a1.7 1.7 0 00-1.1-1.6 1.7 1.7 0 00-1.8.3l-.1.1a2 2 0 11-2.8-2.8l.1-.1a1.7 1.7 0 00.3-1.8 1.7 1.7 0 00-1.5-1H3a2 2 0 110-4h.1a1.7 1.7 0 001.6-1.1 1.7 1.7 0 00-.3-1.8l-.1-.1a2 2 0 112.8-2.8l.1.1a1.7 1.7 0 001.8.3H9a1.7 1.7 0 001-1.5V3a2 2 0 114 0v.1a1.7 1.7 0 001 1.5 1.7 1.7 0 001.8-.3l.1-.1a2 2 0 112.8 2.8l-.1.1a1.7 1.7 0 00-.3 1.8V9a1.7 1.7 0 001.5 1H21a2 2 0 110 4h-.1a1.7 1.7 0 00-1.5 1z"/></>,
    wallet: <><path d="M3 7a2 2 0 012-2h12l4 4v10a2 2 0 01-2 2H5a2 2 0 01-2-2V7z"/><path d="M16 13h2"/></>,
    receipt: <><path d="M5 3h14v18l-3-2-3 2-3-2-3 2-2-1.5V3z"/><path d="M8 8h8M8 12h8M8 16h5"/></>,
    card: <><rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 10h18M7 15h3"/></>,
    sparkle: <><path d="M12 3l1.7 4.5L18 9l-4.3 1.5L12 15l-1.7-4.5L6 9l4.3-1.5L12 3z"/><path d="M19 15l.8 2 2 .8-2 .7L19 21l-.8-2-2-.7 2-.8z"/></>,
    target: <><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5" fill="currentColor"/></>,
    trending: <><path d="M3 17l6-6 4 4 8-8"/><path d="M14 7h7v7"/></>,
    pie: <><path d="M21 12A9 9 0 113 12 9 9 0 0121 12z"/><path d="M12 3v9l8 4"/></>,
    help: <><circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 015 0c0 1.5-2.5 2-2.5 4"/><circle cx="12" cy="17" r="0.5" fill="currentColor"/></>,
    user: <><circle cx="12" cy="8" r="3.5"/><path d="M5 21c0-4 3-7 7-7s7 3 7 7"/></>,
    qr: <><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3M21 14v3M14 18v3h3M21 21h-3"/></>,
    camera: <><path d="M4 8h3l2-2h6l2 2h3a1 1 0 011 1v10a1 1 0 01-1 1H4a1 1 0 01-1-1V9a1 1 0 011-1z"/><circle cx="12" cy="13" r="3.5"/></>,
    moon: <><path d="M21 12.8A9 9 0 0111.2 3a7 7 0 109.8 9.8z"/></>,
    sun: <><circle cx="12" cy="12" r="4"/><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M5.6 18.4L7 17M17 7l1.4-1.4"/></>,
    search: <><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></>,
    filter: <><path d="M4 5h16M7 12h10M10 19h4"/></>,
    calendar: <><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/></>,
    clock: <><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></>,
    edit: <><path d="M4 20h4l11-11-4-4L4 16v4z"/><path d="M14 6l4 4"/></>,
    trash: <><path d="M4 7h16M9 7V5a1 1 0 011-1h4a1 1 0 011 1v2M6 7l1 13a1 1 0 001 1h8a1 1 0 001-1l1-13"/></>,
    share: <><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="6" r="2.5"/><circle cx="18" cy="18" r="2.5"/><path d="M8.2 11l7.6-4M8.2 13l7.6 4"/></>,
    copy: <><rect x="8" y="8" width="13" height="13" rx="2"/><path d="M16 8V5a2 2 0 00-2-2H5a2 2 0 00-2 2v9a2 2 0 002 2h3"/></>,
    info: <><circle cx="12" cy="12" r="9"/><path d="M12 8.5v.01M11 12h1v5h1"/></>,
    upload: <><path d="M12 3v13M7 8l5-5 5 5"/><path d="M5 21h14"/></>,
    download: <><path d="M12 3v13M7 11l5 5 5-5"/><path d="M5 21h14"/></>,
    lock: <><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 018 0v3"/></>,
    mail: <><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/></>,
    phone: <><path d="M5 4h4l2 5-2.5 1.5a11 11 0 005 5L15 13l5 2v4a2 2 0 01-2 2A16 16 0 013 6a2 2 0 012-2z"/></>,
    star: <><path d="M12 3l2.7 5.6 6.3.9-4.5 4.4 1 6.1L12 17l-5.5 3 1-6.1L3 9.5l6.3-.9z"/></>,
    coin: <><circle cx="12" cy="12" r="9"/><path d="M14 9h-3a2 2 0 000 4h2a2 2 0 010 4H9.5M12 7v2M12 15v2"/></>,
    folder: <><path d="M3 7a2 2 0 012-2h4l2 2h8a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V7z"/></>,
    activity: <><path d="M3 12h4l3-8 4 16 3-8h4"/></>,
    dot: <><circle cx="12" cy="12" r="3" fill="currentColor"/></>,
    menu: <><path d="M4 6h16M4 12h16M4 18h16"/></>,
    eye: <><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></>,
    eyeOff: <><path d="M3 3l18 18M10.5 6.5A8 8 0 0112 6c6.5 0 10 7 10 7a17 17 0 01-3.2 4.2M14 14a3 3 0 01-4-4M7 7a17 17 0 00-5 5s3.5 7 10 7c1.5 0 2.8-.3 4-.8"/></>,
    rocket: <><path d="M14 4l6 6-9 9-3-3 9-9-3-3-9 9z"/><path d="M9 15l-3 3 3 3 3-3"/><circle cx="15" cy="9" r="1.2" fill="currentColor"/></>,
  };
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" style={{ flexShrink: 0 }}>
      {paths[name] || paths.dot}
    </svg>
  );
};

// Card primitive
const Card = ({ children, c, d, style = {}, onClick, padded = true, ...rest }) => (
  <div onClick={onClick} style={{
    background: c.surface, borderRadius: 16, padding: padded ? d.cardPad : 0,
    border: `1px solid ${c.border}`, ...style,
    cursor: onClick ? 'pointer' : 'default',
  }} {...rest}>{children}</div>
);

// Pill / chip
const Pill = ({ children, c, color, bg, style = {} }) => (
  <span style={{
    display: 'inline-flex', alignItems: 'center', gap: 4,
    padding: '3px 8px', borderRadius: 999,
    fontSize: 11, fontWeight: 600, letterSpacing: 0.1,
    background: bg || c.primarySoft, color: color || c.text,
    ...style,
  }}>{children}</span>
);

// Section header
const SectionHeader = ({ title, action, c, style = {} }) => (
  <div style={{
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    marginBottom: 10, ...style,
  }}>
    <div style={{ fontSize: 13, fontWeight: 700, letterSpacing: 0.4,
      textTransform: 'uppercase', color: c.textSecondary }}>{title}</div>
    {action}
  </div>
);

// Numeric formatter (RM)
const fmt = (n, opts = {}) => {
  const { decimals = 2, currency = true } = opts;
  const v = Math.abs(n).toLocaleString('en-MY', {
    minimumFractionDigits: decimals, maximumFractionDigits: decimals,
  });
  const sign = n < 0 ? '-' : '';
  return currency ? `${sign}RM ${v}` : `${sign}${v}`;
};

// Avatar
const Avatar = ({ name, size = 36, color, bg }) => {
  const initials = (name || '?').split(' ').slice(0, 2).map(s => s[0]).join('').toUpperCase();
  // deterministic color from name
  const palette = [
    ['#5B6FFF', '#ECEFFF'], ['#00C2A8', '#E0F7F2'], ['#F59E0B', '#FEF3DC'],
    ['#EF4444', '#FDECEC'], ['#3B82F6', '#E8F0FE'], ['#8B5CF6', '#F1EBFE'],
    ['#10B981', '#E5F7EF'], ['#EC4899', '#FCE7F3'],
  ];
  let h = 0;
  for (const ch of (name || '')) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  const [fg, bgC] = palette[h % palette.length];
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%',
      background: bg || bgC, color: color || fg,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontSize: size * 0.4, fontWeight: 700, flexShrink: 0,
      letterSpacing: -0.3,
    }}>{initials}</div>
  );
};

// Button
const Button = ({ children, c, variant = 'primary', size = 'md', onClick, leading, trailing, full, style = {}, disabled }) => {
  const sizes = {
    sm: { pad: '8px 14px', fs: 13, h: 36, rad: 10 },
    md: { pad: '12px 18px', fs: 14, h: 44, rad: 12 },
    lg: { pad: '14px 20px', fs: 15, h: 52, rad: 14 },
  };
  const s = sizes[size];
  const variants = {
    primary: { bg: c.primary, color: c.textOnPrimary, border: 'none' },
    accent: { bg: c.accent, color: '#003830', border: 'none' },
    secondary: { bg: c.surfaceAlt, color: c.text, border: `1px solid ${c.border}` },
    ghost: { bg: 'transparent', color: c.text, border: 'none' },
    danger: { bg: c.dangerSoft, color: c.danger, border: 'none' },
  };
  const v = variants[variant];
  return (
    <button onClick={onClick} disabled={disabled} style={{
      padding: s.pad, fontSize: s.fs, fontWeight: 600, height: s.h, borderRadius: s.rad,
      background: v.bg, color: v.color, border: v.border,
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      width: full ? '100%' : 'auto', cursor: disabled ? 'not-allowed' : 'pointer',
      opacity: disabled ? 0.5 : 1, fontFamily: 'inherit', letterSpacing: 0.1,
      transition: 'transform 0.1s, opacity 0.15s', WebkitTapHighlightColor: 'transparent',
      ...style,
    }}
      onMouseDown={e => e.currentTarget.style.transform = 'scale(0.98)'}
      onMouseUp={e => e.currentTarget.style.transform = 'scale(1)'}
      onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}
    >
      {leading}{children}{trailing}
    </button>
  );
};

// Status bar (Android-style minimal)
const StatusBar = ({ c, dark }) => (
  <div style={{
    height: 28, padding: '0 18px',
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    fontSize: 12, fontWeight: 600, color: dark ? '#fff' : c.text,
    background: 'transparent', flexShrink: 0,
  }}>
    <span>9:41</span>
    <div style={{ display: 'flex', gap: 5, alignItems: 'center' }}>
      <Icon name="dot" size={6} />
      <svg width="14" height="10" viewBox="0 0 14 10"><path d="M0 8h2v2H0zM4 6h2v4H4zM8 3h2v7H8zM12 0h2v10h-2z" fill={dark ? '#fff' : c.text}/></svg>
      <svg width="20" height="10" viewBox="0 0 20 10"><rect x="0" y="1" width="17" height="8" rx="2" stroke={dark ? '#fff' : c.text} strokeWidth="1" fill="none"/><rect x="2" y="3" width="11" height="4" rx="0.5" fill={dark ? '#fff' : c.text}/><rect x="18" y="4" width="2" height="2" rx="0.5" fill={dark ? '#fff' : c.text}/></svg>
    </div>
  </div>
);

// Nav home indicator
const NavBar = ({ c, dark }) => (
  <div style={{
    height: 22, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
  }}>
    <div style={{ width: 110, height: 4, borderRadius: 2,
      background: dark ? 'rgba(255,255,255,0.6)' : c.text, opacity: 0.4 }}/>
  </div>
);

// Tooltip / coach mark
const Tooltip = ({ children, c, position = 'bottom', arrow = true, style = {} }) => {
  const arrowStyle = {
    bottom: { bottom: '100%', left: '50%', transform: 'translateX(-50%)', borderColor: `transparent transparent ${c.text} transparent`, borderWidth: '0 6px 8px 6px' },
    top: { top: '100%', left: '50%', transform: 'translateX(-50%)', borderColor: `${c.text} transparent transparent transparent`, borderWidth: '8px 6px 0 6px' },
  };
  return (
    <div style={{
      background: c.text, color: c.surface, borderRadius: 10, padding: '10px 12px',
      fontSize: 13, fontWeight: 500, lineHeight: 1.4, position: 'relative',
      boxShadow: c.shadowLg, maxWidth: 240, ...style,
    }}>
      {arrow && <span style={{
        position: 'absolute', width: 0, height: 0, border: 'solid', ...arrowStyle[position],
      }}/>}
      {children}
    </div>
  );
};

Object.assign(window, { Icon, Card, Pill, SectionHeader, fmt, Avatar, Button, StatusBar, NavBar, Tooltip });
