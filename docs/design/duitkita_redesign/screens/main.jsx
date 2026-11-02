// All main screens for DuitKita prototype
// Home, Groups list, Group detail, Add expense modal, Help overlay, Empty states

// ─── Mock data ─────────────────────────────────────────────────
const MOCK = {
  user: { name: 'Aiman Hakim', initials: 'AH' },
  groups: [
    { id: 'g1', name: 'Hakim Family', desc: 'Monthly contribution to mum', members: 5, monthly: 500, paid: 3, color: 'catGroups', icon: 'users', emoji: '🏠' },
    { id: 'g2', name: 'KL Trip 2026', desc: 'Squad getaway · split bills', members: 6, monthly: 0, paid: 0, color: 'accent', icon: 'sparkle', emoji: '✈️' },
    { id: 'g3', name: 'Office Lunch Pool', desc: 'Weekly food kitty', members: 8, monthly: 80, paid: 5, color: 'catBills', icon: 'receipt', emoji: '🍱' },
  ],
  debts: [
    { id: 'd1', title: 'Toyota Vios', subtitle: 'Maybank · 4y left', monthly: 1280, remaining: 61440, paid: false, type: 'debt' },
    { id: 'd2', title: 'PTPTN Loan', subtitle: '6y 2mo left', monthly: 320, remaining: 23680, paid: true, type: 'debt' },
  ],
  bills: [
    { id: 'b1', title: 'Unifi Fibre', subtitle: 'Due 15th · auto', monthly: 139, paid: true, type: 'bill' },
    { id: 'b2', title: 'Astro Sports Pack', subtitle: 'Due 20th', monthly: 89.90, paid: false, type: 'bill' },
    { id: 'b3', title: 'Spotify Family', subtitle: 'Due 28th', monthly: 24.90, paid: false, type: 'bill' },
  ],
  group_members: [
    { name: 'Aiman Hakim', role: 'You · Admin', status: 'confirmed', amount: 100 },
    { name: 'Mama Siti', role: 'Member', status: 'confirmed', amount: 100 },
    { name: 'Adik Aliya', role: 'Member', status: 'pending', amount: 100 },
    { name: 'Abang Faiz', role: 'Member', status: 'unpaid', amount: 100 },
    { name: 'Kak Nurul', role: 'Member', status: 'confirmed', amount: 100 },
  ],
  group_activity: [
    { who: 'Mama Siti', what: 'paid RM100', when: '2h ago', status: 'confirmed', icon: 'check' },
    { who: 'Adik Aliya', what: 'submitted payment', when: '5h ago', status: 'pending', icon: 'clock' },
    { who: 'You', what: 'added expense "Hari Raya groceries"', when: '1d ago', status: 'info', icon: 'receipt' },
    { who: 'Kak Nurul', what: 'paid RM100', when: '2d ago', status: 'confirmed', icon: 'check' },
  ],
};

// ─── Bottom nav ────────────────────────────────────────────────
const BottomNav = ({ c, route, setRoute, showJdt }) => {
  const items = [
    { id: 'home', icon: 'home', label: 'Home' },
    { id: 'groups', icon: 'users', label: 'Groups' },
    { id: 'add', icon: 'plusBold', label: '', special: true },
    { id: 'debts', icon: 'bank', label: 'Debts' },
    showJdt ? { id: 'jdt', icon: 'soccer', label: 'JDT' } : { id: 'profile', icon: 'user', label: 'Profile' },
  ];
  return (
    <div style={{
      background: c.surface, borderTop: `1px solid ${c.border}`,
      padding: '8px 8px 4px', display: 'flex', alignItems: 'center', justifyContent: 'space-around',
      flexShrink: 0,
    }}>
      {items.map(it => {
        if (it.special) return (
          <button key={it.id} onClick={() => setRoute('add')} style={{
            width: 52, height: 52, borderRadius: 18,
            background: c.text, border: 'none', cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: `0 6px 16px ${c.text}40`, marginTop: -16,
          }}>
            <Icon name="plus" size={22} color={c.surface} strokeWidth={2.5}/>
          </button>
        );
        const active = route === it.id;
        return (
          <button key={it.id} onClick={() => setRoute(it.id)} style={{
            background: 'none', border: 'none', cursor: 'pointer',
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
            padding: '6px 14px', color: active ? c.text : c.textTertiary,
            fontFamily: 'inherit',
          }}>
            <Icon name={it.icon} size={22} strokeWidth={active ? 2.2 : 1.7}/>
            <span style={{ fontSize: 10, fontWeight: active ? 700 : 500 }}>{it.label}</span>
          </button>
        );
      })}
    </div>
  );
};

// ─── Header (consistent across screens) ───────────────────────
const ScreenHeader = ({ c, title, subtitle, leading, trailing, large, style = {} }) => (
  <div style={{
    padding: large ? '8px 20px 4px' : '10px 20px',
    display: 'flex', alignItems: 'center', gap: 12,
    background: c.bg, ...style,
  }}>
    {leading}
    <div style={{ flex: 1, minWidth: 0 }}>
      <h1 style={{
        fontSize: large ? 26 : 18, fontWeight: 800, color: c.text,
        letterSpacing: -0.5, margin: 0, lineHeight: 1.15,
      }}>{title}</h1>
      {subtitle && <div style={{ fontSize: 13, color: c.textSecondary, marginTop: 2 }}>{subtitle}</div>}
    </div>
    {trailing}
  </div>
);

// ─── HOME ──────────────────────────────────────────────────────
const Home = ({ c, d, setRoute, openGroup, setHelp, firstTimeTip, dismissTip }) => {
  const totalGroupsMonthly = MOCK.groups.reduce((s, g) => s + g.monthly, 0);
  const totalDebtsMonthly = MOCK.debts.reduce((s, x) => s + x.monthly, 0);
  const totalBillsMonthly = MOCK.bills.reduce((s, x) => s + x.monthly, 0);
  const total = totalGroupsMonthly + totalDebtsMonthly + totalBillsMonthly;
  const paidThisMonth = MOCK.bills.filter(b => b.paid).reduce((s, x) => s + x.monthly, 0)
    + MOCK.debts.filter(b => b.paid).reduce((s, x) => s + x.monthly, 0);
  const remaining = total - paidThisMonth;
  const pct = Math.round((paidThisMonth / total) * 100);

  return (
    <div style={{ flex: 1, overflow: 'auto', background: c.bg }}>
      {/* Greeting header */}
      <div style={{ padding: '12px 20px 4px', display: 'flex', alignItems: 'center', gap: 12 }}>
        <Avatar name={MOCK.user.name} size={42}/>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 13, color: c.textSecondary, fontWeight: 500 }}>Selamat petang,</div>
          <div style={{ fontSize: 17, fontWeight: 800, color: c.text, letterSpacing: -0.3 }}>
            {MOCK.user.name.split(' ')[0]}
          </div>
        </div>
        <button onClick={() => setHelp(true)} style={{
          width: 40, height: 40, borderRadius: 12, background: c.surface,
          border: `1px solid ${c.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center',
          cursor: 'pointer', position: 'relative',
        }}>
          <Icon name="help" size={20} color={c.text}/>
        </button>
        <button style={{
          width: 40, height: 40, borderRadius: 12, background: c.surface,
          border: `1px solid ${c.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center',
          cursor: 'pointer', position: 'relative',
        }}>
          <Icon name="bell" size={20} color={c.text}/>
          <span style={{ position: 'absolute', top: 8, right: 9, width: 8, height: 8,
            borderRadius: 4, background: c.danger, border: `2px solid ${c.surface}` }}/>
        </button>
      </div>

      {/* Hero balance card */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{
          background: c.headerGradient, borderRadius: 22, padding: 20, color: '#fff',
          position: 'relative', overflow: 'hidden',
        }}>
          <div style={{ position: 'absolute', right: -40, top: -40, width: 180, height: 180,
            borderRadius: '50%', background: `radial-gradient(circle, ${c.accent}30, transparent 70%)` }}/>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', position: 'relative' }}>
            <div>
              <div style={{ fontSize: 12, opacity: 0.7, fontWeight: 600, letterSpacing: 0.4, textTransform: 'uppercase' }}>
                Monthly commitments · May
              </div>
              <div style={{ fontSize: 36, fontWeight: 800, letterSpacing: -1.2, marginTop: 6, lineHeight: 1 }}>
                {fmt(total)}
              </div>
            </div>
            <div style={{
              background: 'rgba(255,255,255,0.12)', border: '1px solid rgba(255,255,255,0.18)',
              padding: '6px 10px', borderRadius: 10, fontSize: 11, fontWeight: 700,
              display: 'flex', alignItems: 'center', gap: 4,
            }}>
              <Icon name="trending" size={12} color={c.accent}/>
              <span style={{ color: c.accent }}>On track</span>
            </div>
          </div>

          {/* Progress */}
          <div style={{ marginTop: 18 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 6 }}>
              <span style={{ opacity: 0.85 }}>Paid {fmt(paidThisMonth, { decimals: 0 })}</span>
              <span style={{ opacity: 0.85 }}>{fmt(remaining, { decimals: 0 })} left</span>
            </div>
            <div style={{ height: 6, borderRadius: 3, background: 'rgba(255,255,255,0.15)', overflow: 'hidden' }}>
              <div style={{ height: '100%', width: `${pct}%`, background: c.accent, borderRadius: 3 }}/>
            </div>
            <div style={{ marginTop: 8, fontSize: 11, opacity: 0.7, fontWeight: 600 }}>
              {pct}% of monthly commitments cleared
            </div>
          </div>
        </div>

        {/* First-time tip on hero */}
        {firstTimeTip === 'home-hero' && (
          <div style={{ marginTop: 10, animation: 'fadeIn 0.4s' }}>
            <Tooltip c={c} position="bottom">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12 }}>
                <span>This card shows everything you owe this month — groups, loans, and bills combined.</span>
                <button onClick={dismissTip} style={{
                  background: 'none', border: 'none', color: c.surface, cursor: 'pointer',
                  fontSize: 12, fontWeight: 700, opacity: 0.7, padding: 0, whiteSpace: 'nowrap',
                }}>Got it</button>
              </div>
            </Tooltip>
          </div>
        )}
      </div>

      {/* Quick actions */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
          {[
            { icon: 'plusBold', label: 'Add expense', bg: c.accentSoft, fg: c.accentDeep, route: 'add' },
            { icon: 'qr', label: 'Pay QR', bg: c.catDebtsSoft, fg: c.catDebts, route: 'add' },
            { icon: 'users', label: 'New group', bg: c.catGroupsSoft, fg: c.catGroups, route: 'groups' },
            { icon: 'pie', label: 'Insights', bg: c.catBillsSoft, fg: c.catBills, route: 'home' },
          ].map(a => (
            <button key={a.label} onClick={() => setRoute(a.route)} style={{
              background: c.surface, border: `1px solid ${c.border}`, borderRadius: 16,
              padding: '14px 6px 12px', cursor: 'pointer', display: 'flex',
              flexDirection: 'column', alignItems: 'center', gap: 8, fontFamily: 'inherit',
            }}>
              <div style={{
                width: 36, height: 36, borderRadius: 11, background: a.bg,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <Icon name={a.icon} size={18} color={a.fg}/>
              </div>
              <span style={{ fontSize: 11, fontWeight: 600, color: c.text, letterSpacing: -0.1 }}>{a.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Up next — needs attention */}
      <div style={{ padding: `${d.sectionGap}px 20px 0` }}>
        <SectionHeader c={c} title="Up next" action={
          <button style={{ background: 'none', border: 'none', color: c.textSecondary,
            fontSize: 12, fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>View all</button>
        }/>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <UpNextItem c={c} d={d}
            icon="receipt" iconBg={c.warningSoft} iconColor={c.warning}
            title="Astro Sports Pack" subtitle="Bill · due in 12 days" amount={89.90}
            cta="Pay" onClick={() => setRoute('add')}/>
          <UpNextItem c={c} d={d}
            icon="users" iconBg={c.catGroupsSoft} iconColor={c.catGroups}
            title="Hakim Family" subtitle="2 members haven't paid" amount={200}
            cta="Review" onClick={() => openGroup('g1')} muted/>
          <UpNextItem c={c} d={d}
            icon="bank" iconBg={c.catDebtsSoft} iconColor={c.catDebts}
            title="Toyota Vios" subtitle="Loan · due 28 May" amount={1280}
            cta="Pay" onClick={() => setRoute('add')}/>
        </div>
      </div>

      {/* Breakdown */}
      <div style={{ padding: `${d.sectionGap}px 20px 0` }}>
        <SectionHeader c={c} title="Where your money goes"/>
        <Card c={c} d={d}>
          <BreakdownRow c={c} icon="users" iconBg={c.catGroupsSoft} iconColor={c.catGroups}
            label="Groups" sub={`${MOCK.groups.length} active`} amount={totalGroupsMonthly}
            onClick={() => setRoute('groups')}/>
          <Divider c={c}/>
          <BreakdownRow c={c} icon="bank" iconBg={c.catDebtsSoft} iconColor={c.catDebts}
            label="Loans" sub={`${MOCK.debts.length} active`} amount={totalDebtsMonthly}
            onClick={() => setRoute('debts')}/>
          <Divider c={c}/>
          <BreakdownRow c={c} icon="receipt" iconBg={c.catBillsSoft} iconColor={c.catBills}
            label="Bills" sub={`${MOCK.bills.length} subscriptions`} amount={totalBillsMonthly}
            onClick={() => setRoute('debts')}/>
        </Card>
      </div>

      <div style={{ height: 24 }}/>
    </div>
  );
};

const UpNextItem = ({ c, d, icon, iconBg, iconColor, title, subtitle, amount, cta, onClick, muted }) => (
  <Card c={c} d={d} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
    <div style={{ width: 40, height: 40, borderRadius: 12, background: iconBg,
      display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
      <Icon name={icon} size={20} color={iconColor}/>
    </div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 14, fontWeight: 700, color: c.text, letterSpacing: -0.2 }}>{title}</div>
      <div style={{ fontSize: 12, color: c.textSecondary, marginTop: 1 }}>{subtitle}</div>
    </div>
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4 }}>
      <div style={{ fontSize: 14, fontWeight: 800, color: c.text, letterSpacing: -0.3 }}>{fmt(amount)}</div>
      <button onClick={onClick} style={{
        padding: '4px 10px', borderRadius: 8, fontSize: 11, fontWeight: 700,
        background: muted ? c.surfaceAlt : c.text, color: muted ? c.text : c.surface,
        border: muted ? `1px solid ${c.border}` : 'none', cursor: 'pointer', fontFamily: 'inherit',
      }}>{cta}</button>
    </div>
  </Card>
);

const Divider = ({ c }) => <div style={{ height: 1, background: c.border, margin: '4px 0' }}/>;

const BreakdownRow = ({ c, icon, iconBg, iconColor, label, sub, amount, onClick }) => (
  <button onClick={onClick} style={{
    width: '100%', background: 'none', border: 'none', padding: '8px 0',
    display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer', fontFamily: 'inherit',
  }}>
    <div style={{ width: 36, height: 36, borderRadius: 10, background: iconBg,
      display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <Icon name={icon} size={18} color={iconColor}/>
    </div>
    <div style={{ flex: 1, textAlign: 'left' }}>
      <div style={{ fontSize: 14, fontWeight: 700, color: c.text }}>{label}</div>
      <div style={{ fontSize: 11, color: c.textTertiary }}>{sub}</div>
    </div>
    <div style={{ fontSize: 15, fontWeight: 800, color: c.text, letterSpacing: -0.3 }}>{fmt(amount, { decimals: 0 })}</div>
    <Icon name="chevronRight" size={16} color={c.textTertiary}/>
  </button>
);

// ─── GROUPS LIST ───────────────────────────────────────────────
const GroupsList = ({ c, d, openGroup, isEmpty }) => {
  const groups = isEmpty ? [] : MOCK.groups;
  if (groups.length === 0) {
    return (
      <div style={{ flex: 1, overflow: 'auto', background: c.bg }}>
        <ScreenHeader c={c} large title="Groups" subtitle="Split bills with people you trust"/>
        <EmptyState c={c} d={d}
          icon="users"
          title="No groups yet"
          body="Start a group with family, housemates, or your travel squad. Split monthly bills, track who paid, and settle up without the awkwardness."
          ctaLabel="Create your first group"
          tips={['Set a monthly amount', 'Add members by phone or email', 'Admin approves payments']}/>
      </div>
    );
  }
  return (
    <div style={{ flex: 1, overflow: 'auto', background: c.bg }}>
      <ScreenHeader c={c} large title="Groups" subtitle={`${groups.length} active · ${fmt(groups.reduce((s,g)=>s+g.monthly,0), {decimals:0})}/mo`}
        trailing={
          <button style={{ width: 40, height: 40, borderRadius: 12, background: c.surface,
            border: `1px solid ${c.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <Icon name="plus" size={20} color={c.text}/>
          </button>
        }/>

      <div style={{ padding: '8px 20px 0', display: 'flex', gap: 8, overflowX: 'auto' }}>
        {['All', 'Active', 'Pending', 'Settled'].map((t, i) => (
          <button key={t} style={{
            padding: '8px 14px', borderRadius: 999, fontSize: 12, fontWeight: 700,
            background: i === 0 ? c.text : c.surface, color: i === 0 ? c.surface : c.text,
            border: i === 0 ? 'none' : `1px solid ${c.border}`, cursor: 'pointer',
            fontFamily: 'inherit', whiteSpace: 'nowrap',
          }}>{t}</button>
        ))}
      </div>

      <div style={{ padding: '14px 20px 24px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {groups.map(g => <GroupCard key={g.id} c={c} d={d} g={g} onClick={() => openGroup(g.id)}/>)}
      </div>
    </div>
  );
};

const GroupCard = ({ c, d, g, onClick }) => {
  const pct = g.members > 0 ? Math.round((g.paid / g.members) * 100) : 0;
  return (
    <Card c={c} d={d} onClick={onClick} style={{ padding: 14 }}>
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
        <div style={{
          width: 44, height: 44, borderRadius: 12, fontSize: 22,
          background: c[g.color + 'Soft'] || c.primarySoft,
          display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        }}>{g.emoji}</div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
            <div style={{ fontSize: 15, fontWeight: 800, color: c.text, letterSpacing: -0.3 }}>{g.name}</div>
            <Icon name="chevronRight" size={16} color={c.textTertiary}/>
          </div>
          <div style={{ fontSize: 12, color: c.textSecondary, marginTop: 2 }}>{g.desc}</div>

          {g.monthly > 0 ? (
            <div style={{ marginTop: 10 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 5 }}>
                <span style={{ fontSize: 11, fontWeight: 600, color: c.textSecondary }}>
                  {g.paid}/{g.members} paid this month
                </span>
                <span style={{ fontSize: 13, fontWeight: 800, color: c.text, letterSpacing: -0.2 }}>
                  {fmt(g.monthly, { decimals: 0 })}<span style={{ fontSize: 10, fontWeight: 600, color: c.textTertiary }}>/mo</span>
                </span>
              </div>
              <div style={{ height: 4, borderRadius: 2, background: c.surfaceAlt, overflow: 'hidden' }}>
                <div style={{ height: '100%', width: `${pct}%`, background: c[g.color] || c.accent, borderRadius: 2, transition: 'width 0.3s' }}/>
              </div>
            </div>
          ) : (
            <div style={{ marginTop: 10, display: 'flex', alignItems: 'center', gap: 6 }}>
              <Pill c={c} bg={c.accentSoft} color={c.accentDeep}>One-off split</Pill>
              <span style={{ fontSize: 11, color: c.textSecondary, fontWeight: 500 }}>{g.members} members</span>
            </div>
          )}
        </div>
      </div>
    </Card>
  );
};

// ─── GROUP DETAIL ──────────────────────────────────────────────
const GroupDetail = ({ c, d, groupId, back, openAddExpense }) => {
  const g = MOCK.groups.find(x => x.id === groupId) || MOCK.groups[0];
  const [tab, setTab] = React.useState('members');
  const paidPct = g.members > 0 ? Math.round((g.paid / g.members) * 100) : 0;
  return (
    <div style={{ flex: 1, overflow: 'auto', background: c.bg }}>
      <div style={{ padding: '10px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
        <button onClick={back} style={{ width: 40, height: 40, borderRadius: 12,
          background: c.surface, border: `1px solid ${c.border}`, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="chevronLeft" size={20} color={c.text}/>
        </button>
        <div style={{ flex: 1 }}/>
        <button style={{ width: 40, height: 40, borderRadius: 12,
          background: c.surface, border: `1px solid ${c.border}`, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="share" size={18} color={c.text}/>
        </button>
        <button style={{ width: 40, height: 40, borderRadius: 12,
          background: c.surface, border: `1px solid ${c.border}`, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="settings" size={18} color={c.text}/>
        </button>
      </div>

      {/* Group hero */}
      <div style={{ padding: '0 20px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '4px 4px 14px' }}>
          <div style={{
            width: 54, height: 54, borderRadius: 16, fontSize: 28,
            background: c[g.color + 'Soft'] || c.primarySoft,
            display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
          }}>{g.emoji}</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 22, fontWeight: 800, color: c.text, letterSpacing: -0.5 }}>{g.name}</div>
            <div style={{ fontSize: 13, color: c.textSecondary, marginTop: 2 }}>{g.desc}</div>
          </div>
        </div>

        {/* Stats card */}
        <Card c={c} d={d} style={{ padding: 0, overflow: 'hidden' }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr' }}>
            {[
              { label: 'Per member', value: fmt(g.monthly / g.members, { decimals: 0 }) },
              { label: 'Members', value: g.members },
              { label: 'This month', value: `${g.paid}/${g.members}` },
            ].map((s, i) => (
              <div key={i} style={{
                padding: '14px 12px', textAlign: 'center',
                borderRight: i < 2 ? `1px solid ${c.border}` : 'none',
              }}>
                <div style={{ fontSize: 18, fontWeight: 800, color: c.text, letterSpacing: -0.4 }}>{s.value}</div>
                <div style={{ fontSize: 10, color: c.textSecondary, fontWeight: 600,
                  textTransform: 'uppercase', letterSpacing: 0.4, marginTop: 2 }}>{s.label}</div>
              </div>
            ))}
          </div>
          <div style={{ padding: '0 14px 14px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11,
              fontWeight: 600, color: c.textSecondary, marginBottom: 5 }}>
              <span>Collection progress</span>
              <span style={{ color: c.accentDeep }}>{paidPct}%</span>
            </div>
            <div style={{ height: 5, borderRadius: 3, background: c.surfaceAlt, overflow: 'hidden' }}>
              <div style={{ height: '100%', width: `${paidPct}%`, background: c.accent, borderRadius: 3 }}/>
            </div>
          </div>
        </Card>

        {/* Action row */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginTop: 12 }}>
          <Button c={c} variant="primary" full leading={<Icon name="qr" size={16}/>}>Pay my share</Button>
          <Button c={c} variant="secondary" full onClick={openAddExpense}
            leading={<Icon name="plus" size={16}/>}>Add expense</Button>
        </div>
      </div>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: 4, padding: '20px 20px 0',
        borderBottom: `1px solid ${c.border}`, marginTop: 12 }}>
        {['members', 'activity', 'expenses'].map(t => (
          <button key={t} onClick={() => setTab(t)} style={{
            padding: '10px 14px', background: 'none', border: 'none', cursor: 'pointer',
            fontSize: 13, fontWeight: 700, color: tab === t ? c.text : c.textTertiary,
            borderBottom: tab === t ? `2px solid ${c.text}` : '2px solid transparent',
            marginBottom: -1, fontFamily: 'inherit', textTransform: 'capitalize',
          }}>{t}</button>
        ))}
      </div>

      <div style={{ padding: '14px 20px 24px' }}>
        {tab === 'members' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {MOCK.group_members.map((m, i) => (
              <Card key={i} c={c} d={d} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 12 }}>
                <Avatar name={m.name} size={40}/>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 14, fontWeight: 700, color: c.text }}>{m.name}</div>
                  <div style={{ fontSize: 11, color: c.textSecondary }}>{m.role}</div>
                </div>
                <StatusBadge c={c} status={m.status}/>
              </Card>
            ))}
          </div>
        )}
        {tab === 'activity' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {MOCK.group_activity.map((a, i) => {
              const colorMap = { confirmed: c.success, pending: c.warning, info: c.textSecondary };
              const bgMap = { confirmed: c.successSoft, pending: c.warningSoft, info: c.surfaceAlt };
              return (
                <Card key={i} c={c} d={d} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 12 }}>
                  <div style={{ width: 36, height: 36, borderRadius: 10, background: bgMap[a.status],
                    display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <Icon name={a.icon} size={16} color={colorMap[a.status]}/>
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 13, color: c.text }}>
                      <span style={{ fontWeight: 700 }}>{a.who}</span> {a.what}
                    </div>
                    <div style={{ fontSize: 11, color: c.textTertiary, marginTop: 1 }}>{a.when}</div>
                  </div>
                </Card>
              );
            })}
          </div>
        )}
        {tab === 'expenses' && (
          <EmptyState c={c} d={d} compact icon="receipt" title="No expenses yet"
            body="Group expenses (groceries, dinner) will show here. Add one to start tracking who paid what."
            ctaLabel="Add expense" onCta={openAddExpense}/>
        )}
      </div>
    </div>
  );
};

const StatusBadge = ({ c, status }) => {
  const map = {
    confirmed: { bg: c.successSoft, fg: c.success, label: 'Paid' },
    pending: { bg: c.warningSoft, fg: c.warning, label: 'Pending' },
    unpaid: { bg: c.dangerSoft, fg: c.danger, label: 'Unpaid' },
  };
  const m = map[status];
  return (
    <span style={{
      padding: '4px 10px', borderRadius: 999, fontSize: 11, fontWeight: 700,
      background: m.bg, color: m.fg,
    }}>{m.label}</span>
  );
};

// ─── EMPTY STATE ───────────────────────────────────────────────
const EmptyState = ({ c, d, icon, title, body, ctaLabel, onCta, tips, compact }) => (
  <div style={{ padding: compact ? '20px 16px' : '40px 24px', textAlign: 'center' }}>
    <div style={{
      width: compact ? 64 : 88, height: compact ? 64 : 88, borderRadius: 24,
      background: c.surface, border: `1px solid ${c.border}`, margin: '0 auto',
      display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative',
    }}>
      <Icon name={icon} size={compact ? 28 : 38} color={c.textSecondary} strokeWidth={1.6}/>
      <div style={{ position: 'absolute', right: -6, top: -6, width: 28, height: 28,
        borderRadius: 8, background: c.accent, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Icon name="plus" size={14} color="#003830" strokeWidth={2.4}/>
      </div>
    </div>
    <h2 style={{ fontSize: compact ? 18 : 22, fontWeight: 800, color: c.text,
      margin: '20px 0 8px', letterSpacing: -0.4 }}>{title}</h2>
    <p style={{ fontSize: 14, color: c.textSecondary, lineHeight: 1.5,
      maxWidth: 280, margin: '0 auto 20px' }}>{body}</p>
    {ctaLabel && (
      <Button c={c} size="md" onClick={onCta} leading={<Icon name="plus" size={16}/>}>
        {ctaLabel}
      </Button>
    )}
    {tips && (
      <div style={{ marginTop: 28, padding: 14, background: c.surface,
        border: `1px solid ${c.border}`, borderRadius: 14, textAlign: 'left' }}>
        <div style={{ fontSize: 11, fontWeight: 700, color: c.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>How it works</div>
        {tips.map((t, i) => (
          <div key={i} style={{ display: 'flex', gap: 10, padding: '6px 0', alignItems: 'flex-start' }}>
            <div style={{ width: 18, height: 18, borderRadius: 6, background: c.accentSoft,
              color: c.accentDeep, fontSize: 11, fontWeight: 800, display: 'flex',
              alignItems: 'center', justifyContent: 'center', flexShrink: 0, marginTop: 1 }}>{i + 1}</div>
            <div style={{ fontSize: 13, color: c.text, fontWeight: 500 }}>{t}</div>
          </div>
        ))}
      </div>
    )}
  </div>
);

// ─── ADD EXPENSE MODAL ─────────────────────────────────────────
const AddExpense = ({ c, d, close }) => {
  const [step, setStep] = React.useState(1);
  const [type, setType] = React.useState('group');
  const [amount, setAmount] = React.useState('120.00');
  const [title, setTitle] = React.useState('Hari Raya groceries');
  const [group, setGroup] = React.useState('g1');

  return (
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(11,31,58,0.5)', backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'flex-end', zIndex: 100 }}>
      <div style={{
        width: '100%', background: c.bg, borderRadius: '24px 24px 0 0',
        maxHeight: '92%', display: 'flex', flexDirection: 'column',
        animation: 'slideUp 0.3s cubic-bezier(.22,1,.36,1)',
      }}>
        <div style={{ padding: '12px 0', display: 'flex', justifyContent: 'center' }}>
          <div style={{ width: 36, height: 4, borderRadius: 2, background: c.borderStrong }}/>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', padding: '0 16px 12px' }}>
          <h2 style={{ flex: 1, margin: 0, fontSize: 18, fontWeight: 800, color: c.text, letterSpacing: -0.3 }}>
            {step === 1 ? 'New entry' : step === 2 ? 'Details' : 'Review & confirm'}
          </h2>
          <button onClick={close} style={{ width: 36, height: 36, borderRadius: 10,
            background: c.surface, border: `1px solid ${c.border}`, cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="close" size={18} color={c.text}/>
          </button>
        </div>

        {/* Stepper */}
        <div style={{ display: 'flex', gap: 6, padding: '0 16px 12px' }}>
          {[1, 2, 3].map(s => (
            <div key={s} style={{ flex: 1, height: 4, borderRadius: 2,
              background: s <= step ? c.accent : c.border, transition: 'background 0.3s' }}/>
          ))}
        </div>

        <div style={{ overflow: 'auto', padding: '8px 20px 12px', flex: 1 }}>
          {step === 1 && (
            <>
              <Label c={c}>What kind of entry?</Label>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
                {[
                  { id: 'group', icon: 'users', label: 'Group expense', sub: 'Split with members' },
                  { id: 'bill', icon: 'receipt', label: 'Bill / subscription', sub: 'Recurring payment' },
                  { id: 'debt', icon: 'bank', label: 'Loan payment', sub: 'Pay down a debt' },
                  { id: 'personal', icon: 'wallet', label: 'Personal', sub: 'Just for you' },
                ].map(o => (
                  <button key={o.id} onClick={() => setType(o.id)} style={{
                    background: type === o.id ? c.accentSoft : c.surface,
                    border: `1.5px solid ${type === o.id ? c.accent : c.border}`,
                    borderRadius: 14, padding: 14, cursor: 'pointer', textAlign: 'left',
                    fontFamily: 'inherit',
                  }}>
                    <Icon name={o.icon} size={20} color={type === o.id ? c.accentDeep : c.text}/>
                    <div style={{ fontSize: 13, fontWeight: 700, color: c.text, marginTop: 8 }}>{o.label}</div>
                    <div style={{ fontSize: 11, color: c.textSecondary, marginTop: 2 }}>{o.sub}</div>
                  </button>
                ))}
              </div>
            </>
          )}

          {step === 2 && (
            <>
              <Label c={c}>Amount</Label>
              <div style={{
                background: c.surface, border: `1px solid ${c.border}`, borderRadius: 14,
                padding: '18px 16px', display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 16,
              }}>
                <span style={{ fontSize: 18, fontWeight: 700, color: c.textTertiary }}>RM</span>
                <input value={amount} onChange={e => setAmount(e.target.value)} style={{
                  flex: 1, border: 'none', outline: 'none', background: 'none',
                  fontSize: 32, fontWeight: 800, color: c.text, letterSpacing: -0.8,
                  fontFamily: 'inherit', minWidth: 0,
                }}/>
              </div>

              <Label c={c}>What's it for?</Label>
              <Field c={c} value={title} onChange={setTitle} placeholder="e.g. Dinner at Nasi Kandar"/>

              {type === 'group' && (
                <>
                  <Label c={c}>Group</Label>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 12 }}>
                    {MOCK.groups.map(g => (
                      <button key={g.id} onClick={() => setGroup(g.id)} style={{
                        background: group === g.id ? c.accentSoft : c.surface,
                        border: `1.5px solid ${group === g.id ? c.accent : c.border}`,
                        borderRadius: 12, padding: 12, cursor: 'pointer',
                        display: 'flex', alignItems: 'center', gap: 10, fontFamily: 'inherit', textAlign: 'left',
                      }}>
                        <div style={{ width: 36, height: 36, borderRadius: 10, fontSize: 20,
                          background: c[g.color + 'Soft'] || c.primarySoft, display: 'flex',
                          alignItems: 'center', justifyContent: 'center' }}>{g.emoji}</div>
                        <div style={{ flex: 1 }}>
                          <div style={{ fontSize: 13, fontWeight: 700, color: c.text }}>{g.name}</div>
                          <div style={{ fontSize: 11, color: c.textSecondary }}>{g.members} members</div>
                        </div>
                        {group === g.id && <Icon name="check" size={18} color={c.accentDeep} strokeWidth={2.5}/>}
                      </button>
                    ))}
                  </div>
                </>
              )}

              <Label c={c}>Receipt (optional)</Label>
              <button style={{
                width: '100%', background: c.surface, border: `1.5px dashed ${c.borderStrong}`,
                borderRadius: 14, padding: '20px 16px', cursor: 'pointer', display: 'flex',
                alignItems: 'center', justifyContent: 'center', gap: 8, fontFamily: 'inherit',
                color: c.textSecondary, fontSize: 13, fontWeight: 600,
              }}>
                <Icon name="camera" size={18}/> Attach photo or PDF
              </button>
            </>
          )}

          {step === 3 && (
            <>
              <Card c={c} d={d} style={{ padding: 18, marginBottom: 12 }}>
                <div style={{ fontSize: 11, fontWeight: 700, color: c.textSecondary, textTransform: 'uppercase', letterSpacing: 0.4 }}>You're adding</div>
                <div style={{ fontSize: 36, fontWeight: 800, color: c.text, letterSpacing: -1, marginTop: 4 }}>RM {amount}</div>
                <div style={{ fontSize: 14, color: c.textSecondary, marginTop: 4 }}>{title}</div>
              </Card>
              <Card c={c} d={d}>
                <ReviewRow c={c} label="Type" value={type === 'group' ? 'Group expense' : type}/>
                {type === 'group' && <ReviewRow c={c} label="Group" value={MOCK.groups.find(x => x.id === group)?.name}/>}
                <ReviewRow c={c} label="Date" value="8 May 2026"/>
                <ReviewRow c={c} label="Paid by" value="You"/>
                {type === 'group' && (
                  <ReviewRow c={c} label="Split" value={`${MOCK.groups.find(x => x.id === group)?.members} members · RM ${(parseFloat(amount) / (MOCK.groups.find(x => x.id === group)?.members || 1)).toFixed(2)} each`}/>
                )}
              </Card>
              <div style={{ marginTop: 12, padding: 12, background: c.infoSoft, borderRadius: 12,
                display: 'flex', gap: 10, alignItems: 'flex-start' }}>
                <Icon name="info" size={16} color={c.info} strokeWidth={2}/>
                <div style={{ fontSize: 12, color: c.text, lineHeight: 1.4 }}>
                  Group admins will receive a notification to approve this expense.
                </div>
              </div>
            </>
          )}
        </div>

        {/* Footer */}
        <div style={{ padding: '12px 20px 16px', borderTop: `1px solid ${c.border}`,
          background: c.surface, display: 'flex', gap: 10 }}>
          {step > 1 && (
            <Button c={c} variant="secondary" size="lg" onClick={() => setStep(step - 1)}
              leading={<Icon name="chevronLeft" size={16}/>}>Back</Button>
          )}
          <Button c={c} size="lg" full
            onClick={() => step < 3 ? setStep(step + 1) : close()}
            trailing={step < 3 ? <Icon name="arrowRight" size={16}/> : <Icon name="check" size={16}/>}>
            {step < 3 ? 'Continue' : 'Confirm & submit'}
          </Button>
        </div>
      </div>
    </div>
  );
};

const Label = ({ c, children }) => (
  <div style={{ fontSize: 12, fontWeight: 700, color: c.textSecondary,
    textTransform: 'uppercase', letterSpacing: 0.4, marginBottom: 8, marginTop: 4 }}>
    {children}
  </div>
);

const Field = ({ c, value, onChange, placeholder }) => (
  <input value={value} onChange={e => onChange(e.target.value)} placeholder={placeholder}
    style={{
      width: '100%', background: c.surface, border: `1px solid ${c.border}`,
      borderRadius: 12, padding: '14px 14px', fontSize: 14, color: c.text,
      fontFamily: 'inherit', outline: 'none', marginBottom: 16, boxSizing: 'border-box',
    }}/>
);

const ReviewRow = ({ c, label, value }) => (
  <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0',
    borderBottom: `1px solid ${c.border}`, fontSize: 13 }}>
    <span style={{ color: c.textSecondary }}>{label}</span>
    <span style={{ color: c.text, fontWeight: 700 }}>{value}</span>
  </div>
);

// ─── HELP / TOUR OVERLAY ───────────────────────────────────────
const HelpOverlay = ({ c, d, close, restartTour, restartOnboarding }) => (
  <div style={{ position: 'absolute', inset: 0, background: 'rgba(11,31,58,0.5)', backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'flex-end', zIndex: 100 }}>
    <div style={{
      width: '100%', background: c.bg, borderRadius: '24px 24px 0 0',
      maxHeight: '90%', display: 'flex', flexDirection: 'column',
      animation: 'slideUp 0.3s cubic-bezier(.22,1,.36,1)',
    }}>
      <div style={{ padding: '12px 0 0', display: 'flex', justifyContent: 'center' }}>
        <div style={{ width: 36, height: 4, borderRadius: 2, background: c.borderStrong }}/>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', padding: '14px 20px 4px' }}>
        <h2 style={{ flex: 1, margin: 0, fontSize: 22, fontWeight: 800, color: c.text, letterSpacing: -0.4 }}>
          How DuitKita works
        </h2>
        <button onClick={close} style={{ width: 36, height: 36, borderRadius: 10,
          background: c.surface, border: `1px solid ${c.border}`, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="close" size={18} color={c.text}/>
        </button>
      </div>
      <p style={{ padding: '0 20px', margin: 0, fontSize: 14, color: c.textSecondary }}>
        Quick guide to the three things this app does.
      </p>

      <div style={{ overflow: 'auto', padding: '20px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {[
          { icon: 'users', color: c.catGroups, bg: c.catGroupsSoft, title: 'Groups',
            steps: ['Create a group, set monthly amount', 'Invite members by phone or email', 'Members pay → admin approves', 'Track who\'s paid each month'] },
          { icon: 'bank', color: c.catDebts, bg: c.catDebtsSoft, title: 'Loans',
            steps: ['Add a loan with monthly payment', 'Mark each month as paid', 'See remaining balance shrink', 'Get reminded before due date'] },
          { icon: 'receipt', color: c.catBills, bg: c.catBillsSoft, title: 'Bills',
            steps: ['Add subscriptions (Astro, Spotify, etc.)', 'Pick a due date', 'Tick when paid', 'Auto-rolls over each month'] },
        ].map(g => (
          <Card key={g.title} c={c} d={d} style={{ padding: 14 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 10 }}>
              <div style={{ width: 36, height: 36, borderRadius: 10, background: g.bg,
                display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Icon name={g.icon} size={18} color={g.color}/>
              </div>
              <div style={{ fontSize: 16, fontWeight: 800, color: c.text, letterSpacing: -0.3 }}>{g.title}</div>
            </div>
            <ol style={{ margin: 0, paddingLeft: 0, listStyle: 'none' }}>
              {g.steps.map((s, i) => (
                <li key={i} style={{ display: 'flex', gap: 10, padding: '5px 0', fontSize: 13, color: c.text, fontWeight: 500 }}>
                  <span style={{ width: 18, height: 18, borderRadius: 6, background: g.bg, color: g.color,
                    fontSize: 11, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>{i+1}</span>
                  {s}
                </li>
              ))}
            </ol>
          </Card>
        ))}

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginTop: 4 }}>
          <Button c={c} variant="secondary" full onClick={restartTour}
            leading={<Icon name="target" size={16}/>}>Replay tips</Button>
          <Button c={c} variant="secondary" full onClick={restartOnboarding}
            leading={<Icon name="rocket" size={16}/>}>Show intro</Button>
        </div>
      </div>
    </div>
  </div>
);

// ─── PLACEHOLDER SCREENS ───────────────────────────────────────
const SimpleScreen = ({ c, d, title, icon, body }) => (
  <div style={{ flex: 1, overflow: 'auto', background: c.bg }}>
    <ScreenHeader c={c} large title={title}/>
    <EmptyState c={c} d={d} icon={icon} title={`${title} go here`} body={body}
      ctaLabel="Add your first one"/>
  </div>
);

Object.assign(window, { BottomNav, Home, GroupsList, GroupDetail, AddExpense, HelpOverlay, EmptyState, SimpleScreen, ScreenHeader, MOCK });
