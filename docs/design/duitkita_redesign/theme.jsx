// Design tokens for DuitKita — calm fintech direction
// Light + dark mode, density variants

const TOKENS = {
  light: {
    // Surfaces
    bg: '#F2F4F7',           // app background (off-white, slightly cool)
    surface: '#FFFFFF',       // cards
    surfaceAlt: '#F7F9FB',    // tile inside card
    border: '#E6EAF0',
    borderStrong: '#D1D7E0',

    // Text
    text: '#0B1F3A',          // deep navy
    textSecondary: '#5B6B82',
    textTertiary: '#8B97AA',
    textOnPrimary: '#FFFFFF',

    // Brand
    primary: '#0B1F3A',       // deep navy
    primarySoft: '#E8ECF3',
    accent: '#00C2A8',        // mint
    accentSoft: '#E0F7F2',
    accentDeep: '#008C7A',

    // Status
    success: '#10B981',
    successSoft: '#E5F7EF',
    warning: '#F59E0B',
    warningSoft: '#FEF3DC',
    danger: '#EF4444',
    dangerSoft: '#FDECEC',
    info: '#3B82F6',
    infoSoft: '#E8F0FE',

    // Category colors (calmer)
    catGroups: '#5B6FFF',     // soft indigo
    catGroupsSoft: '#ECEFFF',
    catDebts: '#3B82F6',      // blue
    catDebtsSoft: '#E8F0FE',
    catBills: '#F59E0B',      // amber
    catBillsSoft: '#FEF3DC',

    // Header gradient (subtle, not harsh)
    headerGradient: 'linear-gradient(180deg, #0B1F3A 0%, #11264A 100%)',

    shadow: '0 1px 2px rgba(11,31,58,0.04), 0 4px 12px rgba(11,31,58,0.04)',
    shadowLg: '0 10px 30px rgba(11,31,58,0.08)',
  },
  dark: {
    bg: '#070C18',
    surface: '#0F1626',
    surfaceAlt: '#161E32',
    border: '#1E2942',
    borderStrong: '#2A3854',

    text: '#F4F6FB',
    textSecondary: '#A4B0C5',
    textTertiary: '#6B7A95',
    textOnPrimary: '#0B1F3A',

    primary: '#FFFFFF',
    primarySoft: '#1A2540',
    accent: '#22D3B5',
    accentSoft: '#0F2A28',
    accentDeep: '#22D3B5',

    success: '#22C55E',
    successSoft: '#0F2820',
    warning: '#FBBF24',
    warningSoft: '#2A2010',
    danger: '#F87171',
    dangerSoft: '#2A1414',
    info: '#60A5FA',
    infoSoft: '#0F1F33',

    catGroups: '#818CF8',
    catGroupsSoft: '#1A1E3A',
    catDebts: '#60A5FA',
    catDebtsSoft: '#0F1F33',
    catBills: '#FBBF24',
    catBillsSoft: '#2A2010',

    headerGradient: 'linear-gradient(180deg, #0B1F3A 0%, #14264A 100%)',

    shadow: '0 1px 2px rgba(0,0,0,0.4), 0 4px 12px rgba(0,0,0,0.3)',
    shadowLg: '0 10px 30px rgba(0,0,0,0.5)',
  },
};

const DENSITY = {
  compact: { cardPad: 12, cardGap: 8, listPad: 10, h: 1.35, sectionGap: 16 },
  comfortable: { cardPad: 16, cardGap: 12, listPad: 14, h: 1.45, sectionGap: 24 },
};

const useTheme = (mode = 'light', density = 'comfortable') => {
  const c = TOKENS[mode];
  const d = DENSITY[density];
  return { c, d, mode, density };
};

window.TOKENS = TOKENS;
window.DENSITY = DENSITY;
window.useTheme = useTheme;
