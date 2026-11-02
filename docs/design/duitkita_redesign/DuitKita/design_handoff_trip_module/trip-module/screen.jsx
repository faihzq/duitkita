// DuitKita — Trip module
// Create a trip, then fill its day-by-day itinerary.
// Reuses tokens + chrome from home-redesign/base.jsx (C, Icon, Avatar, StatusBar, BottomNav, HomeIndicator, rm)

// ── Extra glyphs (line icons, matching the base set) ──
const TIcon = ({ name, size = 20, color = 'currentColor', sw = 1.8 }) => {
  const p = {
    car: <><rect x="3" y="10" width="18" height="6" rx="2"/><path d="M6 10l1.6-4h8.8L18 10"/><circle cx="7.5" cy="16.5" r="1.5"/><circle cx="16.5" cy="16.5" r="1.5"/></>,
    ferry: <><path d="M3 17l1.6-5h14.8L21 17"/><path d="M6 12V8h12v4"/><path d="M12 4v4"/><path d="M2 20c1.4 0 1.4 1 2.8 1s1.4-1 2.8-1 1.4 1 2.8 1 1.4-1 2.8-1 1.4 1 2.8 1 1.4-1 2.8-1"/></>,
    boat: <><path d="M4 15h16l-2.2 5H6.2L4 15z"/><path d="M12 3v11M12 3l6 4-6 1.4"/></>,
    cablecar: <><path d="M3 5h18"/><path d="M12 5v3.2"/><rect x="6.5" y="8.2" width="11" height="7.6" rx="2"/><path d="M9.5 8.2v7.6M14.5 8.2v7.6"/></>,
    food: <><path d="M7 3v8M5 3v4a2 2 0 002 2M9 3v4a2 2 0 01-2 2M7 11v10"/><path d="M17.5 3c-1.6 0-2.8 1.8-2.8 5s1.4 3.8 2.8 3.8V21"/></>,
    mosque: <><path d="M4 20v-8a8 8 0 0116 0v8"/><path d="M12 2.5c1.3 1 1.3 2.2 0 3.2-1.3-1-1.3-2.2 0-3.2z"/><path d="M4 20h16"/><path d="M9 20v-4a3 3 0 016 0v4"/></>,
    mountain: <><path d="M3 20l6-11 3.5 5.5L15 10l6 10z"/><path d="M9 9l1.5 2.6"/></>,
    bag: <><path d="M6 8h12l-1 12H7L6 8z"/><path d="M9 8V6.2a3 3 0 016 0V8"/></>,
    camera: <><rect x="3" y="7" width="18" height="13" rx="2.5"/><path d="M8.5 7l1.3-2.5h4.4L15.5 7"/><circle cx="12" cy="13.2" r="3.4"/></>,
    wave: <><path d="M2 11c2 0 2-2 4-2s2 2 4 2 2-2 4-2 2 2 4 2 2-2 4-2"/><path d="M2 16c2 0 2-2 4-2s2 2 4 2 2-2 4-2 2 2 4 2 2-2 4-2"/></>,
    flag: <><path d="M5 21V4"/><path d="M5 4h11l-2 3.2 2 3.2H5"/></>,
    pin: <><path d="M12 21s7-6.4 7-12a7 7 0 10-14 0c0 5.6 7 12 7 12z"/><circle cx="12" cy="9" r="2.4"/></>,
    calendar: <><rect x="3" y="5" width="18" height="16" rx="3"/><path d="M3 10h18M8 3v4M16 3v4"/></>,
    clock: <><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></>,
    chevronLeft: <path d="M15 6l-6 6 6 6"/>,
    chevronRight: <path d="M9 6l6 6-6 6"/>,
    plus: <path d="M12 5v14M5 12h14"/>,
    check: <path d="M5 12l5 5L20 7"/>,
    edit: <><path d="M4 20h4l11-11-4-4L4 16v4z"/><path d="M14 6l4 4"/></>,
    share: <><circle cx="6" cy="12" r="2.4"/><circle cx="18" cy="6" r="2.4"/><circle cx="18" cy="18" r="2.4"/><path d="M8.1 11l7.8-4M8.1 13l7.8 4"/></>,
    route: <><circle cx="6" cy="19" r="2.4"/><circle cx="18" cy="5" r="2.4"/><path d="M8 17.5C14 15 10 9 16 6.5"/></>,
    dot: <circle cx="12" cy="12" r="3" fill="currentColor"/>,
  };
  if (p[name]) return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" style={{ flexShrink: 0 }}>{p[name]}</svg>;
  return <Icon name={name} size={size} color={color} sw={sw}/>;
};

// ── Itinerary stop types → colour + label ──
const TYPE = {
  travel: { color: C.info, soft: C.infoSoft, label: 'Travel' },
  food:   { color: C.warning, soft: C.warningSoft, label: 'Food' },
  sight:  { color: C.catGroups, soft: C.catGroupsSoft, label: 'Activity' },
  stay:   { color: C.accentDeep, soft: C.accentSoft, label: 'Stay' },
  prayer: { color: C.textSecondary, soft: C.surfaceAlt, label: 'Break' },
};

// ── The Langkawi trip data ──
const TRIP = {
  name: 'Langkawi Road Trip',
  sub: 'Perlis · Kedah · Penang · Perak',
  range: '8 – 14 Aug 2026',
  status: 'Tentative',
  travellers: ['Ibu', 'Along', 'Angah', 'Aiman'],
  days: [
    { n: 1, dow: 'Sat', date: '8 Aug', stops: [
      { t: '12:30 PM', title: 'Ibu departs Muar', type: 'travel', icon: 'car' },
      { t: '3:00 PM', title: 'Arrive Kajang', note: 'Pick up Angah', type: 'travel', icon: 'car' },
      { t: '4:00 PM', title: 'Arrive Damansara', note: 'Pick up Along', type: 'travel', icon: 'car' },
      { t: '4:10 PM', title: 'Drive to Ipoh', type: 'travel', icon: 'car' },
      { t: '6:00 PM', title: 'Maghrib at R&R Tapah', note: 'Prayer & rest stop', type: 'prayer', icon: 'mosque' },
      { t: '8:00 PM', title: 'Homestay Ipoh — Tambun', note: 'Check in', type: 'stay', icon: 'home' },
    ]},
    { n: 2, dow: 'Sun', date: '9 Aug', stops: [
      { t: '6:30 AM', title: 'Drive to Penang', type: 'travel', icon: 'car' },
      { t: '8:45 AM', title: 'Breakfast — Fizzy Cafe', type: 'food', icon: 'food' },
      { t: '9:30 AM', title: 'Penang Hill', type: 'sight', icon: 'mountain' },
      { t: '11:00 AM', title: 'Ais kacang', note: 'Penang Hill', type: 'food', icon: 'food' },
      { t: '12:00 PM', title: 'Nasi kandar Penang', type: 'food', icon: 'food' },
      { t: '1:30 PM', title: 'Jeruk Madu Pak Ali', note: 'Seberang Jaya', type: 'sight', icon: 'bag' },
      { t: '3:00 PM', title: 'Pekan Rabu Alor Setar', note: 'Bahulu Emanis', type: 'sight', icon: 'bag' },
      { t: '6:00 PM', title: 'Homestay Alor Setar', note: 'Check in', type: 'stay', icon: 'home' },
    ]},
    { n: 3, dow: 'Mon', date: '10 Aug', stops: [
      { t: '6:01 AM', title: 'Subuh', note: 'Prayer time in', type: 'prayer', icon: 'mosque' },
      { t: '6:20 AM', title: 'Drive to Jeti Kuala Perlis', type: 'travel', icon: 'car' },
      { t: '7:30 AM', title: 'Breakfast — Aminah Pulut Ayam', note: 'Grab & go', type: 'food', icon: 'food' },
      { t: '8:00 AM', title: 'Arrive Jeti Kuala Perlis', type: 'travel', icon: 'pin' },
      { t: '10:00 AM', title: 'Ferry to Langkawi', type: 'travel', icon: 'ferry' },
      { t: '12:00 PM', title: 'Arrive Langkawi', type: 'travel', icon: 'flag' },
      { t: '1:00 PM', title: 'Langkawi Cable Car', type: 'sight', icon: 'cablecar' },
      { t: '4:30 PM', title: 'TS Duty Free', note: 'Padang Mat Sirat', type: 'sight', icon: 'bag' },
      { t: '5:30 PM', title: 'Pasar Malam Ulu Melaka', note: 'Night market', type: 'sight', icon: 'bag' },
      { t: '6:30 PM', title: 'Homestay Alfa Langkawi', note: 'Check in', type: 'stay', icon: 'home' },
    ]},
    { n: 4, dow: 'Tue', date: '11 Aug', stops: [
      { t: '8:00 AM', title: 'Breakfast', type: 'food', icon: 'food' },
      { t: '9:15 AM', title: 'Kilim River Tourism Jetty', type: 'travel', icon: 'pin' },
      { t: '10:00 AM', title: 'Mangrove Tour by boat', type: 'sight', icon: 'boat' },
      { t: '4:00 PM', title: 'Eagle Square & Maha Tower', note: 'OOTD spot', type: 'sight', icon: 'camera' },
      { t: '5:00 PM', title: 'TS Duty Free — Kuah', type: 'sight', icon: 'bag' },
      { t: '6:30 PM', title: 'Back to Homestay Alfa', type: 'stay', icon: 'home' },
    ]},
    { n: 5, dow: 'Wed', date: '12 Aug', stops: [
      { t: '7:30 AM', title: 'Head out for breakfast', type: 'travel', icon: 'car' },
      { t: '7:45 AM', title: 'Breakfast — Pantai Cenang', type: 'food', icon: 'food' },
      { t: '9:00 AM', title: 'Island Hopping / Underwater World', note: 'By boat', type: 'sight', icon: 'boat' },
      { t: '2:00 PM', title: 'Water sports', note: 'Pantai Cenang', type: 'sight', icon: 'wave' },
      { t: '6:00 PM', title: 'Pasar Malam Kuah', note: 'Night market', type: 'sight', icon: 'bag' },
    ]},
    { n: 6, dow: 'Thu', date: '13 Aug', stops: [
      { t: '8:30 AM', title: 'Breakfast + checkout homestay', type: 'food', icon: 'food' },
      { t: '10:00 AM', title: 'Perniagaan Haji Ismail Group', type: 'sight', icon: 'bag' },
      { t: '12:30 PM', title: 'Tanjung Lembong Port', type: 'travel', icon: 'pin' },
      { t: '1:00 PM', title: 'Ferry to mainland', type: 'travel', icon: 'ferry' },
      { t: '3:00 PM', title: 'Arrive Kuala Perlis Jetty', type: 'travel', icon: 'flag' },
      { t: '5:00 PM', title: 'Hajah Siti Hasil Laut', note: 'Tanjung Dawai · 2nd branch', type: 'sight', icon: 'bag' },
      { t: '7:00 PM', title: 'Homestay Sungai Petani', note: 'Check in', type: 'stay', icon: 'home' },
    ]},
    { n: 7, dow: 'Fri', date: '14 Aug', stops: [
      { t: '10:00 AM', title: 'Head home', type: 'travel', icon: 'car' },
      { t: '1:00 PM', title: 'Nasi Bambu Sungai Kelah', note: 'Perak', type: 'food', icon: 'food' },
    ]},
  ],
};
TRIP.stopCount = TRIP.days.reduce((a, d) => a + d.stops.length, 0);

// ── Place details: map query + short about (keyed by stop title) ──
const DETAILS = {
  'Maghrib at R&R Tapah': { q: 'R&R Tapah, PLUS Highway, Perak', about: 'Northbound rest & service area on the PLUS highway. Surau, toilets, food court and fuel — the natural Maghrib and stretch stop between Damansara and Ipoh.' },
  'Homestay Ipoh — Tambun': { q: 'Tambun, Ipoh, Perak', about: 'Overnight base in Tambun, on Ipoh’s limestone-hill fringe. Close to hot springs and the morning road to Penang.' },
  'Breakfast — Fizzy Cafe': { q: 'Fizzy Cafe Penang', about: 'Popular Penang breakfast cafe — fuel up before heading up Penang Hill.' },
  'Penang Hill': { q: 'Penang Hill, Air Itam, Penang', about: 'Ride the funicular to 833 m for cool air and island views over George Town. Try the famous ais kacang at the top.' },
  'Nasi kandar Penang': { q: 'Nasi Kandar Penang', about: 'Penang’s signature rice with mixed curries — a must-eat lunch on the island.' },
  'Jeruk Madu Pak Ali': { q: 'Jeruk Madu Pak Ali Seberang Jaya', about: 'Well-known preserved-fruit (jeruk) stop in Seberang Jaya — good for road snacks and gifts.' },
  'Pekan Rabu Alor Setar': { q: 'Pekan Rabu, Alor Setar, Kedah', about: 'Kedah’s landmark market complex. Grab Bahulu Emanis and local produce before checking in.' },
  'Homestay Alor Setar': { q: 'Alor Setar, Kedah', about: 'Overnight in the state capital — an early start tomorrow for the Kuala Perlis ferry.' },
  'Drive to Jeti Kuala Perlis': { q: 'Kuala Perlis Ferry Terminal', about: 'Jetty for ferries to Langkawi. Aim to arrive early — the first boats fill fast.' },
  'Breakfast — Aminah Pulut Ayam': { q: 'Aminah Pulut Ayam Kuala Perlis', about: 'Local favourite for pulut ayam — grab & go before boarding.' },
  'Arrive Jeti Kuala Perlis': { q: 'Kuala Perlis Ferry Terminal', about: 'Main ferry terminal in Perlis. Buy tickets, park, and queue for the Langkawi boat.' },
  'Ferry to Langkawi': { q: 'Kuala Perlis Ferry Terminal', about: 'Roughly 1h15 crossing to Kuah, Langkawi. Cars stay on the mainland — arrange island transport.' },
  'Langkawi Cable Car': { q: 'Langkawi SkyCab, Oriental Village', about: 'SkyCab up Gunung Machinchang to the SkyBridge — the island’s top view. At Oriental Village, Teluk Burau.' },
  'TS Duty Free': { q: 'TS Duty Free Padang Matsirat Langkawi', about: 'Langkawi is duty-free — chocolates, kitchenware and more at Padang Mat Sirat prices.' },
  'Pasar Malam Ulu Melaka': { q: 'Pasar Malam Ulu Melaka Langkawi', about: 'Local night market — cheap eats and fresh fruit near the homestay.' },
  'Homestay Alfa Langkawi': { q: 'Ulu Melaka, Langkawi', about: 'Three-night island base near Ulu Melaka — central for beaches and Kuah.' },
  'Kilim River Tourism Jetty': { q: 'Kilim Karst Geoforest Park Jetty Langkawi', about: 'Launch point for the Kilim mangrove & geopark boat tours in the island’s northeast.' },
  'Mangrove Tour by boat': { q: 'Kilim Karst Geoforest Park Langkawi', about: 'Boat through limestone karst mangroves — eagles, bat caves and fish farms. Around 3–4 hours.' },
  'Eagle Square & Maha Tower': { q: 'Dataran Lang Eagle Square Kuah Langkawi', about: 'Langkawi’s giant eagle statue on the Kuah waterfront, beside the new Maha Tower — the classic OOTD shot.' },
  'TS Duty Free — Kuah': { q: 'TS Duty Free Kuah Langkawi', about: 'Kuah-town duty-free outlet — last-minute chocolates and souvenirs.' },
  'Breakfast — Pantai Cenang': { q: 'Pantai Cenang, Langkawi', about: 'The island’s liveliest beach strip — breakfast spots, then straight onto the water.' },
  'Island Hopping / Underwater World': { q: 'Underwater World Langkawi Pantai Cenang', about: 'Island-hopping boat (Dayang Bunting lake, eagle feeding, Beras Basah) or Underwater World aquarium at Cenang.' },
  'Water sports': { q: 'Pantai Cenang Water Sports Langkawi', about: 'Jet-ski, parasailing and banana boat right off Pantai Cenang.' },
  'Pasar Malam Kuah': { q: 'Pasar Malam Kuah Langkawi', about: 'Kuah town night market — dinner and local snacks.' },
  'Perniagaan Haji Ismail Group': { q: 'Perniagaan Haji Ismail Group Langkawi', about: 'Big duty-free & souvenir emporium — stock up before the ferry home.' },
  'Tanjung Lembong Port': { q: 'Tanjung Lembong Jetty Langkawi', about: 'Alternative Langkawi jetty for the crossing back to the Perlis mainland.' },
  'Ferry to mainland': { q: 'Kuala Perlis Ferry Terminal', about: 'Return crossing to Kuala Perlis — collect the car and continue to Kedah.' },
  'Hajah Siti Hasil Laut': { q: 'Hajah Siti Hasil Laut Tanjung Dawai', about: 'Famed dried-seafood & keropok stop at Tanjung Dawai (2nd branch) — great for gifts.' },
  'Homestay Sungai Petani': { q: 'Sungai Petani, Kedah', about: 'Final overnight in Kedah before the drive south tomorrow.' },
  'Nasi Bambu Sungai Kelah': { q: 'Nasi Bambu Sungai Kelah Sungkai Perak', about: 'Rice cooked in bamboo by the Sungai Kelah river in Perak — a scenic last-day lunch on the way home.' },
};
const mapsSearch = (q) => 'https://www.google.com/maps/search/?api=1&query=' + encodeURIComponent(q);
const mapsDir = (q) => 'https://www.google.com/maps/dir/?api=1&destination=' + encodeURIComponent(q) + '&travelmode=driving';
// Chain a day's mappable stops into one driving route (origin → waypoints → destination)
const mapsDayRoute = (day) => {
  const pts = day.stops.filter(s => s.type !== 'prayer').map(s => detailFor(s).q);
  if (pts.length < 2) return mapsDir(pts[0] || day.stops[0] && detailFor(day.stops[0]).q || '');
  const origin = pts[0], destination = pts[pts.length - 1], wp = pts.slice(1, -1);
  let u = 'https://www.google.com/maps/dir/?api=1&travelmode=driving&origin=' + encodeURIComponent(origin) + '&destination=' + encodeURIComponent(destination);
  if (wp.length) u += '&waypoints=' + wp.map(encodeURIComponent).join('%7C');
  return u;
};
// Approx drive to reach a stop from the previous one (keyed by stop title)
const LEGS = {
  'Arrive Kajang': '~2 h 30 · 175 km', 'Arrive Damansara': '~45 min · 30 km',
  'Maghrib at R&R Tapah': '~1 h 40 · 155 km', 'Homestay Ipoh — Tambun': '~1 h · 75 km',
  'Breakfast — Fizzy Cafe': '~2 h · 165 km', 'Penang Hill': '~35 min · 13 km',
  'Jeruk Madu Pak Ali': '~40 min · 22 km', 'Pekan Rabu Alor Setar': '~1 h 10 · 90 km',
  'Homestay Alor Setar': '~15 min · 6 km',
  'Arrive Jeti Kuala Perlis': '~50 min · 45 km', 'Ferry to Langkawi': '~1 h 15 (ferry)',
  'Arrive Langkawi': '—', 'Langkawi Cable Car': '~30 min · 18 km',
  'TS Duty Free': '~15 min · 7 km', 'Pasar Malam Ulu Melaka': '~15 min · 8 km', 'Homestay Alfa Langkawi': '~10 min · 4 km',
  'Kilim River Tourism Jetty': '~30 min · 20 km', 'Eagle Square & Maha Tower': '~40 min · 25 km', 'TS Duty Free — Kuah': '~10 min · 3 km', 'Back to Homestay Alfa': '~30 min · 18 km',
  'Breakfast — Pantai Cenang': '~5 min · 2 km', 'Pasar Malam Kuah': '~25 min · 15 km',
  'Tanjung Lembong Port': '~35 min · 20 km', 'Ferry to mainland': '~1 h 30 (ferry)',
  'Hajah Siti Hasil Laut': '~45 min · 40 km', 'Homestay Sungai Petani': '~50 min · 45 km',
  'Nasi Bambu Sungai Kelah': '~2 h 30 · 200 km',
};
const detailFor = (s) => {
  const d = DETAILS[s.title] || {};
  const q = d.q || (s.note ? `${s.title} ${s.note}` : s.title);
  const fallback = { travel: 'A leg of the journey — open the map to navigate and gauge drive time.', food: 'A food stop on the route — tap directions to find it.', sight: 'A stop worth a visit — open the map to see what’s around.', stay: 'Tonight’s stay — tap directions to drive there.', prayer: 'A short break on the road.' };
  return { q, about: d.about || fallback[s.type] || 'Open the map to navigate here.' };
};

// Sum a day's leg estimates into total drive time + distance
const dayTotals = (day) => {
  let mins = 0, km = 0;
  for (const s of day.stops) {
    const v = LEGS[s.title]; if (!v || v === '—') continue;
    const h = v.match(/(\d+)\s*h/); const m = v.match(/(\d+)\s*min/);
    if (h) mins += parseInt(h[1]) * 60; if (m) mins += parseInt(m[1]);
    const k = v.match(/(\d+)\s*km/); if (k) km += parseInt(k[1]);
  }
  const hh = Math.floor(mins / 60), mm = mins % 60;
  const time = hh ? `${hh} h${mm ? ' ' + mm + ' min' : ''}` : `${mm} min`;
  return { time, km, mins };
};

// ── Navigation (clickable prototype) ──
const Nav = React.createContext(() => {});
const useNav = () => React.useContext(Nav);

// ── Shared bits ──
const BackHeader = ({ title, sub, trailing, onDark, back }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '6px 16px 14px' }}>
    <button onClick={back} style={{ width: 42, height: 42, borderRadius: 13, background: onDark ? 'rgba(255,255,255,0.12)' : C.surfaceAlt, border: onDark ? 'none' : `1px solid ${C.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', flexShrink: 0 }}>
      <TIcon name="chevronLeft" size={20} color={onDark ? '#fff' : C.text} sw={2.2}/>
    </button>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 20, fontWeight: 800, color: onDark ? '#fff' : C.text, letterSpacing: -0.4 }}>{title}</div>
      {sub && <div style={{ fontSize: 12.5, color: onDark ? 'rgba(255,255,255,0.7)' : C.textSecondary, fontWeight: 600, marginTop: 1 }}>{sub}</div>}
    </div>
    {trailing}
  </div>
);

const AvatarStack = ({ names, size = 30, onDark }) => (
  <div style={{ display: 'flex', alignItems: 'center' }}>
    {names.map((n, i) => (
      <div key={n} style={{ marginLeft: i ? -10 : 0, borderRadius: '50%', border: `2px solid ${onDark ? '#12294E' : C.surface}`, zIndex: names.length - i }}>
        <Avatar name={n} size={size}/>
      </div>
    ))}
  </div>
);

// ══════════════ 1 · MY TRIPS (list) ══════════════
const TripCard = ({ trip }) => {
  const st = trip.status === 'Confirmed'
    ? { c: C.accentDeep, bg: C.accentSoft } : trip.status === 'Settled'
    ? { c: C.textSecondary, bg: C.surfaceAlt } : { c: C.warning, bg: C.warningSoft };
  return (
    <div onClick={trip.onOpen} style={{ background: C.surface, borderRadius: 18, border: `1px solid ${C.border}`, overflow: 'hidden', boxShadow: C.shadow, cursor: 'pointer' }}>
      <div style={{ height: 62, background: trip.band, display: 'flex', alignItems: 'center', gap: 12, padding: '0 16px', position: 'relative' }}>
        <div style={{ width: 40, height: 40, borderRadius: 12, background: 'rgba(255,255,255,0.9)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22 }}>{trip.emoji}</div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 15.5, fontWeight: 800, color: '#fff', letterSpacing: -0.3 }}>{trip.name}</div>
          <div style={{ fontSize: 11.5, color: 'rgba(255,255,255,0.82)', fontWeight: 600 }}>{trip.where}</div>
        </div>
      </div>
      <div style={{ padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
        <TIcon name="calendar" size={16} color={C.textTertiary}/>
        <div style={{ flex: 1, fontSize: 13, fontWeight: 700, color: C.text }}>{trip.range}</div>
        <span style={{ fontSize: 10.5, fontWeight: 800, color: st.c, background: st.bg, padding: '4px 9px', borderRadius: 999, letterSpacing: 0.2 }}>{trip.status}</span>
      </div>
      <div style={{ height: 1, background: C.border, margin: '0 16px' }}/>
      <div style={{ padding: '11px 16px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <AvatarStack names={trip.people} size={26}/>
        <div style={{ flex: 1, fontSize: 12, color: C.textSecondary, fontWeight: 600 }}>{trip.people.length} travellers</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 12, fontWeight: 700, color: C.textSecondary }}>
          <TIcon name="route" size={15} color={C.textTertiary}/>{trip.stops} stops
        </div>
      </div>
    </div>
  );
};

const TripsList = () => {
  const go = useNav();
  const upcoming = [
    { name: 'Langkawi Road Trip', where: 'Perlis · Kedah · Penang · Perak', range: '8 – 14 Aug 2026', status: 'Tentative', emoji: '🦅', band: 'linear-gradient(120deg,#0B1F3A,#1E5A78)', people: TRIP.travellers, stops: TRIP.stopCount, onOpen: () => go('itinerary') },
    { name: 'Cameron Highlands', where: 'Pahang', range: '21 – 23 Mar 2026', status: 'Confirmed', emoji: '🌿', band: 'linear-gradient(120deg,#0B3A2E,#00897B)', people: ['Aiman', 'Nadia', 'Imran', 'Farah', 'Lee', 'Siti'], stops: 12 },
  ];
  const past = [
    { name: 'Melaka Weekend', where: 'Melaka', range: '12 – 13 Jan 2026', status: 'Settled', emoji: '🏛️', band: 'linear-gradient(120deg,#3A2E0B,#7A6410)', people: ['Aiman', 'Nadia', 'Imran'], stops: 9 },
  ];
  return (
    <>
      <StatusBar/>
      <div style={{ padding: '6px 20px 10px', display: 'flex', alignItems: 'flex-end', gap: 12 }}>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 26, fontWeight: 800, color: C.text, letterSpacing: -0.6 }}>Trips</div>
          <div style={{ fontSize: 13, color: C.textSecondary, fontWeight: 600, marginTop: 2 }}>Plan, split & remember every getaway</div>
        </div>
        <button onClick={() => go('new')} style={{ height: 42, padding: '0 16px', borderRadius: 13, background: C.text, border: 'none', color: '#fff', fontSize: 13.5, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', fontFamily: 'inherit' }}>
          <TIcon name="plus" size={17} color="#fff" sw={2.4}/>New
        </button>
      </div>
      <div style={{ flex: 1, overflow: 'auto', background: C.bg, padding: '4px 20px 24px' }}>
        <SecHead title="Upcoming" style={{ marginTop: 8 }}/>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {upcoming.map(t => <TripCard key={t.name} trip={t}/>)}
        </div>
        <SecHead title="Past trips" style={{ marginTop: 22 }}/>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12, opacity: 0.85 }}>
          {past.map(t => <TripCard key={t.name} trip={t}/>)}
        </div>
      </div>
      <BottomNav/>
      <HomeIndicator/>
    </>
  );
};

// ══════════════ 2 · NEW TRIP (create form) ══════════════
const Field = ({ label, children, hint }) => (
  <div style={{ marginBottom: 16 }}>
    <div style={{ fontSize: 12.5, fontWeight: 700, color: C.textSecondary, marginBottom: 7, letterSpacing: 0.1 }}>{label}</div>
    {children}
    {hint && <div style={{ fontSize: 11.5, color: C.textTertiary, marginTop: 6 }}>{hint}</div>}
  </div>
);
const Input = ({ value, placeholder, icon, big }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: 10, background: C.surface, border: `1px solid ${C.border}`, borderRadius: 13, padding: big ? '15px 15px' : '13px 14px' }}>
    {icon && <TIcon name={icon} size={18} color={C.textTertiary}/>}
    <span style={{ flex: 1, fontSize: big ? 16 : 14.5, fontWeight: value ? 700 : 500, color: value ? C.text : C.textTertiary, letterSpacing: -0.2 }}>{value || placeholder}</span>
  </div>
);

const NewTrip = () => {
  const go = useNav();
  return (
  <>
    <StatusBar/>
    <BackHeader title="New trip" back={() => go('trips')}/>
    <div style={{ flex: 1, overflow: 'auto', background: C.bg, padding: '4px 20px 20px' }}>
      <Field label="Trip name">
        <Input value="Langkawi Road Trip" icon="edit" big/>
      </Field>
      <Field label="Destinations" hint="Tap to add each state or city you'll pass through">
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {['Perlis', 'Kedah', 'Penang', 'Perak'].map(d => (
            <span key={d} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, background: C.primarySoft, color: C.text, fontSize: 13, fontWeight: 700, padding: '8px 12px', borderRadius: 999 }}>
              <TIcon name="pin" size={14} color={C.accentDeep}/>{d}
            </span>
          ))}
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, background: C.surface, color: C.textSecondary, fontSize: 13, fontWeight: 700, padding: '8px 12px', borderRadius: 999, border: `1px dashed ${C.borderStrong}` }}>
            <TIcon name="plus" size={14} color={C.textSecondary} sw={2.2}/>Add
          </span>
        </div>
      </Field>
      <div style={{ display: 'flex', gap: 12 }}>
        <div style={{ flex: 1 }}><Field label="Start date"><Input value="8 Aug 2026" icon="calendar"/></Field></div>
        <div style={{ flex: 1 }}><Field label="End date"><Input value="14 Aug 2026" icon="calendar"/></Field></div>
      </div>
      <Field label="Travellers" hint="They'll see the itinerary and share trip costs">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, background: C.surface, border: `1px solid ${C.border}`, borderRadius: 13, padding: '11px 14px' }}>
          <AvatarStack names={TRIP.travellers} size={34}/>
          <div style={{ flex: 1, fontSize: 13, fontWeight: 700, color: C.text }}>4 added</div>
          <button style={{ width: 34, height: 34, borderRadius: 10, background: C.accentSoft, border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <TIcon name="plus" size={18} color={C.accentDeep} sw={2.2}/>
          </button>
        </div>
      </Field>
      <Field label="Status">
        <div style={{ display: 'flex', gap: 8 }}>
          {[['Tentative', true], ['Confirmed', false]].map(([l, on]) => (
            <div key={l} style={{ flex: 1, textAlign: 'center', padding: '12px 0', borderRadius: 12, fontSize: 13.5, fontWeight: 700, cursor: 'pointer', background: on ? C.text : C.surface, color: on ? '#fff' : C.textSecondary, border: on ? 'none' : `1px solid ${C.border}` }}>{l}</div>
          ))}
        </div>
      </Field>
    </div>
    <div style={{ padding: '12px 20px', background: C.surface, borderTop: `1px solid ${C.border}` }}>
      <button onClick={() => go('itinerary')} style={{ width: '100%', height: 52, borderRadius: 15, background: C.text, border: 'none', color: '#fff', fontSize: 15, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, cursor: 'pointer', fontFamily: 'inherit' }}>
        Create & add itinerary <TIcon name="arrowRight" size={18} color="#fff"/>
      </button>
    </div>
    <HomeIndicator/>
  </>
  );
};

// ══════════════ 3 · ITINERARY (trip detail) ══════════════
const DayTab = ({ d, active, onClick }) => (
  <div onClick={onClick} style={{ flexShrink: 0, minWidth: 58, textAlign: 'center', padding: '9px 12px', borderRadius: 14, cursor: 'pointer', background: active ? C.text : C.surface, border: active ? 'none' : `1px solid ${C.border}` }}>
    <div style={{ fontSize: 10.5, fontWeight: 700, letterSpacing: 0.3, color: active ? 'rgba(255,255,255,0.7)' : C.textTertiary, textTransform: 'uppercase' }}>Day {d.n}</div>
    <div style={{ fontSize: 14, fontWeight: 800, color: active ? '#fff' : C.text, marginTop: 2, letterSpacing: -0.2 }}>{d.date.split(' ')[0]}</div>
    <div style={{ fontSize: 10.5, fontWeight: 600, color: active ? 'rgba(255,255,255,0.7)' : C.textSecondary, marginTop: 1 }}>{d.dow}</div>
  </div>
);

const Stop = ({ s, last }) => {
  const go = useNav();
  const ty = TYPE[s.type];
  return (
    <div style={{ display: 'flex', gap: 12 }}>
      <div style={{ width: 60, flexShrink: 0, textAlign: 'right', paddingTop: 13 }}>
        <div style={{ fontSize: 12.5, fontWeight: 800, color: C.text, letterSpacing: -0.2 }}>{s.t.replace(' ', '')}</div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', flexShrink: 0 }}>
        <div style={{ width: 12, height: 12, borderRadius: 6, background: ty.color, marginTop: 15, border: `3px solid ${C.bg}`, boxShadow: `0 0 0 1.5px ${ty.color}` }}/>
        {!last && <div style={{ flex: 1, width: 2, background: C.border, marginTop: 2, marginBottom: -6 }}/>}
      </div>
      <div style={{ flex: 1, minWidth: 0, paddingBottom: last ? 0 : 12 }}>
        {LEGS[s.title] && LEGS[s.title] !== '—' && (
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5, marginBottom: 7, padding: '3px 9px', borderRadius: 999, background: C.surfaceAlt, border: `1px solid ${C.border}` }}>
            <TIcon name={LEGS[s.title].includes('ferry') ? 'ferry' : 'car'} size={13} color={C.textTertiary}/>
            <span style={{ fontSize: 11, fontWeight: 700, color: C.textSecondary }}>{LEGS[s.title]}</span>
          </div>
        )}
        <div onClick={() => go('detail', s)} style={{ display: 'flex', gap: 11, alignItems: 'center', background: C.surface, border: `1px solid ${C.border}`, borderRadius: 14, padding: '11px 12px', cursor: 'pointer' }}>
          <div style={{ width: 38, height: 38, borderRadius: 11, background: ty.soft, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <TIcon name={s.icon} size={20} color={ty.color}/>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13.5, fontWeight: 700, color: C.text, letterSpacing: -0.2, lineHeight: 1.25 }}>{s.title}</div>
            {s.note && <div style={{ fontSize: 11.5, color: C.textSecondary, marginTop: 2, fontWeight: 500 }}>{s.note}</div>}
          </div>
          <TIcon name="chevronRight" size={18} color={C.textTertiary}/>
        </div>
      </div>
    </div>
  );
};

const Itinerary = ({ activeDay: initDay = 3 }) => {
  const go = useNav();
  const [activeDay, setActiveDay] = React.useState(initDay);
  const day = TRIP.days.find(d => d.n === activeDay);
  return (
    <>
      <div style={{ background: C.headerGradient, color: '#fff', paddingBottom: 4 }}>
        <StatusBar dark/>
        <BackHeader onDark back={() => go('trips')} title={TRIP.name} sub={TRIP.range} trailing={
          <button style={{ width: 42, height: 42, borderRadius: 13, background: 'rgba(255,255,255,0.12)', border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <TIcon name="share" size={19} color="#fff"/>
          </button>
        }/>
        <div style={{ padding: '0 20px 16px', display: 'flex', alignItems: 'center', gap: 10 }}>
          <span style={{ fontSize: 11, fontWeight: 800, color: '#fff', background: 'rgba(245,158,11,0.28)', padding: '4px 10px', borderRadius: 999, letterSpacing: 0.2 }}>● {TRIP.status}</span>
          <span style={{ fontSize: 12.5, color: 'rgba(255,255,255,0.82)', fontWeight: 600 }}>{TRIP.sub}</span>
        </div>
        <div style={{ padding: '0 20px 18px', display: 'flex', alignItems: 'center', gap: 14 }}>
          <AvatarStack names={TRIP.travellers} size={32} onDark/>
          {[['route', `${TRIP.stopCount} stops`], ['calendar', `${TRIP.days.length} days`]].map(([ic, tx]) => (
            <div key={tx} style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12.5, fontWeight: 700, color: 'rgba(255,255,255,0.9)' }}>
              <TIcon name={ic} size={15} color="rgba(255,255,255,0.7)"/>{tx}
            </div>
          ))}
        </div>
      </div>
      <div style={{ padding: '12px 0 10px', background: C.bg, borderBottom: `1px solid ${C.border}` }}>
        <div style={{ display: 'flex', gap: 8, padding: '0 20px', overflowX: 'auto' }}>
          {TRIP.days.map(d => <DayTab key={d.n} d={d} active={d.n === activeDay} onClick={() => setActiveDay(d.n)}/>)}
        </div>
      </div>
      <div style={{ flex: 1, overflow: 'auto', background: C.bg, padding: '16px 20px 20px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
          <div>
            <div style={{ fontSize: 15, fontWeight: 800, color: C.text, letterSpacing: -0.3 }}>{day.dow}, {day.date} · Day {day.n}</div>
            {dayTotals(day).mins > 0 && (
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4 }}>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 12, fontWeight: 700, color: C.textSecondary }}><TIcon name="clock" size={13} color={C.textTertiary}/>{dayTotals(day).time}</span>
                {dayTotals(day).km > 0 && <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 12, fontWeight: 700, color: C.textSecondary }}><TIcon name="car" size={13} color={C.textTertiary}/>{dayTotals(day).km} km</span>}
              </div>
            )}
          </div>
          <div style={{ fontSize: 12, fontWeight: 700, color: C.textSecondary }}>{day.stops.length} stops</div>
        </div>
        <a href={mapsDayRoute(day)} target="_blank" rel="noopener" style={{ display: 'flex', alignItems: 'center', gap: 11, background: C.accentSoft, border: `1px solid ${C.accent}`, borderRadius: 14, padding: '12px 14px', marginBottom: 16, textDecoration: 'none' }}>
          <div style={{ width: 36, height: 36, borderRadius: 11, background: C.accentDeep, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <TIcon name="route" size={19} color="#fff"/>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13.5, fontWeight: 800, color: C.accentDeep, letterSpacing: -0.2 }}>Navigate this day</div>
            <div style={{ fontSize: 11.5, fontWeight: 600, color: C.accentDeep, opacity: 0.8 }}>Opens the full route in Google Maps</div>
          </div>
          <TIcon name="arrowUpRight" size={18} color={C.accentDeep}/>
        </a>
        {day.stops.map((s, i) => <Stop key={i} s={s} last={i === day.stops.length - 1}/>)}
        <button onClick={() => go('add')} style={{ marginTop: 8, marginLeft: 72, width: 'calc(100% - 72px)', height: 46, borderRadius: 13, background: C.surface, border: `1.5px dashed ${C.borderStrong}`, color: C.textSecondary, fontSize: 13.5, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7, cursor: 'pointer', fontFamily: 'inherit' }}>
          <TIcon name="plus" size={17} color={C.textSecondary} sw={2.2}/>Add a stop
        </button>
      </div>
      <div style={{ padding: '12px 20px', background: C.surface, borderTop: `1px solid ${C.border}`, display: 'flex', gap: 10 }}>
        <button onClick={() => go('add')} style={{ flex: 1, height: 50, borderRadius: 14, background: C.text, border: 'none', color: '#fff', fontSize: 14.5, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, cursor: 'pointer', fontFamily: 'inherit' }}>
          <TIcon name="plus" size={18} color="#fff" sw={2.2}/>Add stop
        </button>
        <button style={{ width: 50, height: 50, borderRadius: 14, background: C.accentSoft, border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
          <TIcon name="wallet" size={20} color={C.accentDeep}/>
        </button>
      </div>
      <HomeIndicator/>
    </>
  );
};

// ══════════════ 4 · ADD STOP (itinerary item form) ══════════════
const AddStop = () => {
  const go = useNav();
  return (
  <>
    <StatusBar/>
    <BackHeader title="Add a stop" sub="Langkawi Road Trip" back={() => go('itinerary')}/>
    <div style={{ flex: 1, overflow: 'auto', background: C.bg, padding: '4px 20px 20px' }}>
      <Field label="Day">
        <div style={{ display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 2 }}>
          {TRIP.days.map(d => (
            <div key={d.n} style={{ flexShrink: 0, textAlign: 'center', padding: '9px 13px', borderRadius: 12, cursor: 'pointer', background: d.n === 3 ? C.text : C.surface, border: d.n === 3 ? 'none' : `1px solid ${C.border}` }}>
              <div style={{ fontSize: 13.5, fontWeight: 800, color: d.n === 3 ? '#fff' : C.text }}>{d.date.split(' ')[0]}</div>
              <div style={{ fontSize: 10, fontWeight: 600, color: d.n === 3 ? 'rgba(255,255,255,0.7)' : C.textTertiary, marginTop: 1 }}>{d.dow}</div>
            </div>
          ))}
        </div>
      </Field>
      <div style={{ display: 'flex', gap: 12 }}>
        <div style={{ flex: 1 }}><Field label="Time"><Input value="10:00 AM" icon="clock"/></Field></div>
      </div>
      <Field label="What's happening?">
        <Input value="Ferry to Langkawi" big/>
      </Field>
      <Field label="Place" hint="Add a location so everyone can navigate there">
        <Input value="Jeti Kuala Perlis" icon="pin"/>
      </Field>
      <Field label="Type">
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {[['travel', 'car'], ['food', 'food'], ['sight', 'camera'], ['stay', 'home'], ['prayer', 'mosque']].map(([k, ic]) => {
            const on = k === 'travel'; const ty = TYPE[k];
            return (
              <span key={k} style={{ display: 'inline-flex', alignItems: 'center', gap: 7, padding: '9px 13px', borderRadius: 999, fontSize: 13, fontWeight: 700, cursor: 'pointer', background: on ? ty.soft : C.surface, color: on ? ty.color : C.textSecondary, border: on ? `1.5px solid ${ty.color}` : `1px solid ${C.border}` }}>
                <TIcon name={ic} size={16} color={on ? ty.color : C.textTertiary}/>{ty.label}
              </span>
            );
          })}
        </div>
      </Field>
      <Field label="Note (optional)">
        <div style={{ background: C.surface, border: `1px solid ${C.border}`, borderRadius: 13, padding: '13px 14px', minHeight: 68, fontSize: 14, color: C.textTertiary, fontWeight: 500 }}>Book ferry tickets the night before — first boat fills up fast.</div>
      </Field>
    </div>
    <div style={{ padding: '12px 20px', background: C.surface, borderTop: `1px solid ${C.border}` }}>
      <button onClick={() => go('itinerary')} style={{ width: '100%', height: 52, borderRadius: 15, background: C.text, border: 'none', color: '#fff', fontSize: 15, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, cursor: 'pointer', fontFamily: 'inherit' }}>
        <TIcon name="check" size={18} color="#fff" sw={2.4}/>Save stop
      </button>
    </div>
    <HomeIndicator/>
  </>
  );
};

// ══════════════ 5 · STOP DETAIL (place + map) ══════════════
const StopDetail = ({ stop }) => {
  const go = useNav();
  const s = stop || TRIP.days[2].stops[4];
  const ty = TYPE[s.type];
  const { q, about } = detailFor(s);
  const place = s.note || s.title;
  return (
    <>
      <div style={{ background: C.headerGradient, color: '#fff' }}>
        <StatusBar dark/>
        <BackHeader onDark back={() => go('itinerary')} title="Stop details" sub={TRIP.name}/>
        <div style={{ padding: '0 22px 22px', display: 'flex', gap: 14, alignItems: 'center' }}>
          <div style={{ width: 56, height: 56, borderRadius: 16, background: 'rgba(255,255,255,0.14)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <TIcon name={s.icon} size={28} color="#fff"/>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 20, fontWeight: 800, color: '#fff', letterSpacing: -0.4, lineHeight: 1.2 }}>{s.title}</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 6 }}>
              <span style={{ fontSize: 11.5, fontWeight: 800, color: '#fff', background: 'rgba(255,255,255,0.18)', padding: '3px 9px', borderRadius: 999 }}>{ty.label}</span>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 12.5, fontWeight: 700, color: 'rgba(255,255,255,0.85)' }}><TIcon name="clock" size={14} color="rgba(255,255,255,0.7)"/>{s.t}</span>
            </div>
          </div>
        </div>
      </div>
      <div style={{ flex: 1, overflow: 'auto', background: C.bg, padding: '18px 20px 20px' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10, background: C.surface, border: `1px solid ${C.border}`, borderRadius: 14, padding: '13px 14px' }}>
          <TIcon name="pin" size={18} color={C.accentDeep}/>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 0.4, textTransform: 'uppercase', color: C.textTertiary }}>Location</div>
            <div style={{ fontSize: 14, fontWeight: 700, color: C.text, marginTop: 2 }}>{place}</div>
          </div>
          {LEGS[s.title] && LEGS[s.title] !== '—' && (
            <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '5px 10px', borderRadius: 999, background: C.surfaceAlt, border: `1px solid ${C.border}`, alignSelf: 'center' }}>
              <TIcon name={LEGS[s.title].includes('ferry') ? 'ferry' : 'car'} size={13} color={C.textTertiary}/>
              <span style={{ fontSize: 11.5, fontWeight: 700, color: C.textSecondary, whiteSpace: 'nowrap' }}>{LEGS[s.title]}</span>
            </div>
          )}
        </div>
        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 0.5, textTransform: 'uppercase', color: C.textSecondary, margin: '20px 0 8px' }}>About this place</div>
        <div style={{ fontSize: 14.5, lineHeight: 1.55, color: C.text, fontWeight: 500 }}>{about}</div>

        <div style={{ marginTop: 20, borderRadius: 16, overflow: 'hidden', border: `1px solid ${C.border}`, background: `linear-gradient(135deg, ${C.accentSoft}, ${C.primarySoft})`, position: 'relative', height: 128 }}>
          <svg width="100%" height="100%" viewBox="0 0 360 128" preserveAspectRatio="none" style={{ position: 'absolute', inset: 0 }}>
            <path d="M-10 40 C60 20 90 70 160 55 S300 20 380 46" stroke={C.borderStrong} strokeWidth="6" fill="none"/>
            <path d="M-10 95 C80 80 120 110 200 92 S320 70 380 96" stroke={C.border} strokeWidth="10" fill="none"/>
            <path d="M110 -10 C120 40 90 80 130 138" stroke={C.border} strokeWidth="5" fill="none"/>
          </svg>
          <div style={{ position: 'absolute', left: '50%', top: '50%', transform: 'translate(-50%,-100%)' }}>
            <TIcon name="pin" size={38} color={C.accentDeep} sw={2.2}/>
          </div>
          <div style={{ position: 'absolute', left: 12, bottom: 10, fontSize: 11.5, fontWeight: 700, color: C.textSecondary, background: 'rgba(255,255,255,0.8)', padding: '3px 8px', borderRadius: 8 }}>Approx. location · tap below to open</div>
        </div>
      </div>
      <div style={{ padding: '12px 20px', background: C.surface, borderTop: `1px solid ${C.border}`, display: 'flex', gap: 10 }}>
        <a href={mapsSearch(q)} target="_blank" rel="noopener" style={{ flex: 1, height: 50, borderRadius: 14, background: C.surfaceAlt, border: `1px solid ${C.border}`, color: C.text, fontSize: 14, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, cursor: 'pointer', textDecoration: 'none' }}>
          <TIcon name="pin" size={18} color={C.text}/>Open in Maps
        </a>
        <a href={mapsDir(q)} target="_blank" rel="noopener" style={{ flex: 1.2, height: 50, borderRadius: 14, background: C.text, border: 'none', color: '#fff', fontSize: 14, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, cursor: 'pointer', textDecoration: 'none' }}>
          <TIcon name="car" size={19} color="#fff"/>Directions
        </a>
      </div>
      <HomeIndicator/>
    </>
  );
};

// ══════════════ CLICKABLE PROTOTYPE ROUTER ══════════════
const TripApp = ({ start = 'trips' }) => {
  const [screen, setScreen] = React.useState(start);
  const [stop, setStop] = React.useState(null);
  const go = React.useCallback((s, payload) => { if (s === 'detail') setStop(payload); setScreen(s); }, []);
  const view = screen === 'trips' ? <TripsList/>
    : screen === 'new' ? <NewTrip/>
    : screen === 'add' ? <AddStop/>
    : screen === 'detail' ? <StopDetail stop={stop}/>
    : <Itinerary/>;
  return <Nav.Provider value={go}>{view}</Nav.Provider>;
};

Object.assign(window, { TripsList, NewTrip, Itinerary, AddStop, StopDetail, TripApp, Nav });
