// Main app shell — routing, state, tweaks integration

const { useState, useEffect } = React;

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "darkMode": false,
  "density": "comfortable",
  "showJdt": false,
  "showOnboarding": true
}/*EDITMODE-END*/;

const App = () => {
  const [tweaks, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const { c, d } = useTheme(tweaks.darkMode ? 'dark' : 'light', tweaks.density);

  const [route, setRoute] = useState('home');
  const [groupId, setGroupId] = useState(null);
  const [showOnboard, setShowOnboard] = useState(tweaks.showOnboarding);
  const [help, setHelp] = useState(false);
  const [tip, setTip] = useState('home-hero');

  useEffect(() => { setShowOnboard(tweaks.showOnboarding); }, [tweaks.showOnboarding]);

  const openGroup = (id) => { setGroupId(id); setRoute('group-detail'); };
  const dismissTip = () => setTip(null);
  const restartTour = () => { setTip('home-hero'); setHelp(false); };
  const restartOnboarding = () => { setShowOnboard(true); setHelp(false); };
  const finishOnboard = () => { setShowOnboard(false); setTweak('showOnboarding', false); };

  let body;
  if (showOnboard) {
    body = <Onboarding c={c} d={d} onDone={finishOnboard}/>;
  } else if (route === 'home') {
    body = <Home c={c} d={d} setRoute={setRoute} openGroup={openGroup}
      setHelp={setHelp} firstTimeTip={tip} dismissTip={dismissTip}/>;
  } else if (route === 'groups') {
    body = <GroupsList c={c} d={d} openGroup={openGroup}/>;
  } else if (route === 'group-detail') {
    body = <GroupDetail c={c} d={d} groupId={groupId} back={() => setRoute('groups')}
      openAddExpense={() => setRoute('add')}/>;
  } else if (route === 'debts') {
    body = <DebtsScreen c={c} d={d}/>;
  } else if (route === 'profile') {
    body = <ProfileScreen c={c} d={d} setHelp={setHelp}/>;
  } else if (route === 'new-expense') {
    body = <NewExpense c={c} d={d} close={() => setRoute('home')}/>;
  } else if (route === 'add-payment') {
    body = <AddPayment c={c} d={d} close={() => setRoute('home')}/>;
  } else if (route === 'expense-approval') {
    body = <ExpenseApproval c={c} d={d} close={() => setRoute('home')}/>;
  } else if (route === 'jdt') {
    body = <SimpleScreen c={c} d={d} title="JDT Matches" icon="soccer"
      body="Upcoming Johor Darul Ta'zim fixtures will appear here."/>;
  }

  const showBottomNav = !showOnboard && route !== 'group-detail' && route !== 'add' && route !== 'new-expense' && route !== 'add-payment' && route !== 'expense-approval';

  return (
    <div style={{
      width: '100%', height: '100%', background: c.bg, color: c.text,
      display: 'flex', flexDirection: 'column', position: 'relative', overflow: 'hidden',
      fontFamily: 'Manrope, system-ui, sans-serif',
    }}>
      <StatusBar c={c} dark={false}/>
      <div style={{ flex: 1, position: 'relative', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        {body}
      </div>
      {route === 'add' && !showOnboard && <AddExpense c={c} d={d} close={() => setRoute('home')}/>}
      {help && <HelpOverlay c={c} d={d} close={() => setHelp(false)}
        restartTour={restartTour} restartOnboarding={restartOnboarding}/>}
      {showBottomNav && <BottomNav c={c} route={route} setRoute={setRoute} showJdt={tweaks.showJdt}/>}
      <NavBar c={c}/>

      <TweaksPanel title="Tweaks">
        <TweakSection label="Theme">
          <TweakRadio label="Mode" value={tweaks.darkMode ? 'dark' : 'light'}
            options={[{value: 'light', label: 'Light'}, {value: 'dark', label: 'Dark'}]}
            onChange={v => setTweak('darkMode', v === 'dark')}/>
        </TweakSection>
        <TweakSection label="Density">
          <TweakRadio label="Spacing" value={tweaks.density}
            options={[{value: 'comfortable', label: 'Comfy'}, {value: 'compact', label: 'Compact'}]}
            onChange={v => setTweak('density', v)}/>
        </TweakSection>
        <TweakSection label="Features">
          <TweakToggle label="JDT football tab" value={tweaks.showJdt}
            onChange={v => setTweak('showJdt', v)}/>
          <TweakButton label="Replay onboarding" onClick={restartOnboarding}/>
          <TweakButton label="Open New Expense screen" onClick={() => setRoute('new-expense')}/>
          <TweakButton label="Open Add Payment screen" onClick={() => setRoute('add-payment')}/>
          <TweakButton label="Open Expense Approval screen" onClick={() => setRoute('expense-approval')}/>
        </TweakSection>
      </TweaksPanel>
    </div>
  );
};

// Inline screens kept here to limit file count
const DebtsScreen = ({ c, d }) => (
  <div style={{ flex: 1, overflow: 'auto', background: c.bg }}>
    <ScreenHeader c={c} large title="Debts & Bills" subtitle="Loans, subscriptions, recurring"
      trailing={
        <button style={{ width: 40, height: 40, borderRadius: 12, background: c.surface,
          border: `1px solid ${c.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
          <Icon name="plus" size={20} color={c.text}/>
        </button>
      }/>
    <div style={{ padding: '8px 20px 0' }}>
      <SectionHeader c={c} title="Loans"/>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {MOCK.debts.map(item => (
          <Card key={item.id} c={c} d={d} style={{ padding: 14 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ width: 40, height: 40, borderRadius: 12, background: c.catDebtsSoft,
                display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Icon name="bank" size={20} color={c.catDebts}/>
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 700, color: c.text }}>{item.title}</div>
                <div style={{ fontSize: 11, color: c.textSecondary }}>{item.subtitle}</div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div style={{ fontSize: 14, fontWeight: 800, color: c.text }}>{fmt(item.monthly, { decimals: 0 })}<span style={{ fontSize: 10, fontWeight: 600, color: c.textTertiary }}>/mo</span></div>
                <div style={{ fontSize: 10, color: c.textTertiary, marginTop: 1 }}>RM {item.remaining.toLocaleString()} left</div>
              </div>
            </div>
            <div style={{ marginTop: 10, height: 4, borderRadius: 2, background: c.surfaceAlt, overflow: 'hidden' }}>
              <div style={{ height: '100%', width: item.paid ? '100%' : '20%', background: item.paid ? c.success : c.catDebts }}/>
            </div>
            <div style={{ marginTop: 6, display: 'flex', justifyContent: 'space-between', fontSize: 10, color: c.textTertiary, fontWeight: 600 }}>
              <span>{item.paid ? 'Paid this month' : 'Unpaid'}</span>
              <span>20% repaid total</span>
            </div>
          </Card>
        ))}
      </div>
      <div style={{ height: 20 }}/>
      <SectionHeader c={c} title="Bills & subscriptions"/>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {MOCK.bills.map(item => (
          <Card key={item.id} c={c} d={d} style={{ padding: 14, display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 40, height: 40, borderRadius: 12, background: c.catBillsSoft,
              display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="receipt" size={20} color={c.catBills}/>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 14, fontWeight: 700, color: c.text }}>{item.title}</div>
              <div style={{ fontSize: 11, color: c.textSecondary }}>{item.subtitle}</div>
            </div>
            <div style={{ fontSize: 14, fontWeight: 800, color: c.text }}>{fmt(item.monthly)}</div>
            <div style={{ width: 28, height: 28, borderRadius: 8, border: `1.5px solid ${item.paid ? c.success : c.borderStrong}`,
              background: item.paid ? c.success : 'transparent',
              display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              {item.paid && <Icon name="check" size={14} color="#fff" strokeWidth={3}/>}
            </div>
          </Card>
        ))}
      </div>
      <div style={{ height: 24 }}/>
    </div>
  </div>
);

const ProfileScreen = ({ c, d, setHelp }) => (
  <div style={{ flex: 1, overflow: 'auto', background: c.bg }}>
    <ScreenHeader c={c} large title="Profile"/>
    <div style={{ padding: '8px 20px' }}>
      <Card c={c} d={d} style={{ padding: 18, display: 'flex', alignItems: 'center', gap: 14 }}>
        <Avatar name={MOCK.user.name} size={56}/>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 17, fontWeight: 800, color: c.text }}>{MOCK.user.name}</div>
          <div style={{ fontSize: 12, color: c.textSecondary }}>aiman@duitkita.my</div>
        </div>
        <Icon name="chevronRight" size={18} color={c.textTertiary}/>
      </Card>
      <div style={{ height: 12 }}/>
      <Card c={c} d={d} padded={false}>
        {[
          { i: 'help', l: 'How DuitKita works', s: 'Quick guided tour', a: () => setHelp(true) },
          { i: 'lock', l: 'Security & privacy', s: 'PIN, biometrics, KYC' },
          { i: 'bell', l: 'Notifications', s: 'Reminders and approvals' },
          { i: 'info', l: 'About', s: 'Version 2.0' },
        ].map((it, i, arr) => (
          <button key={it.l} onClick={it.a} style={{
            width: '100%', background: 'none', border: 'none', cursor: 'pointer',
            padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12,
            borderBottom: i < arr.length - 1 ? `1px solid ${c.border}` : 'none',
            fontFamily: 'inherit', textAlign: 'left',
          }}>
            <div style={{ width: 36, height: 36, borderRadius: 10, background: c.surfaceAlt,
              display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name={it.i} size={18} color={c.text}/>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, fontWeight: 700, color: c.text }}>{it.l}</div>
              <div style={{ fontSize: 11, color: c.textSecondary }}>{it.s}</div>
            </div>
            <Icon name="chevronRight" size={16} color={c.textTertiary}/>
          </button>
        ))}
      </Card>
    </div>
  </div>
);

window.App = App;
