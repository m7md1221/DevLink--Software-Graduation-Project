// Palettes for the three directions. `contrast.mjs` checks every pair and writes docs/design/contrast-report.md.
export const directions = {
  a: {
    slug: 'a-blueprint', name: 'Mukhatat / Blueprint', font: 'plex',
    light: {
      bg: '#F7F6F2', surface: '#FFFFFF', surface2: '#EFEDE6', ink: '#14273A', muted: '#4F5D6B', line: '#D9D6CC', control: '#7D8388',
      primary: '#0E5A83', onPrimary: '#FFFFFF', primaryC: '#DCECF5', onPrimaryC: '#0A3E5B',
      accent: '#A0500A', accentC: '#FAEBD9', onAccentC: '#6E3706',
      success: '#1A6B45', successC: '#DDF0E6', onSuccessC: '#114A30',
      warning: '#855000', warningC: '#FBEBCC', onWarningC: '#5C3700',
      danger: '#B3261E', onDanger: '#FFFFFF', dangerC: '#FBE4E2', onDangerC: '#7E1A15',
      neutralC: '#E9E7E0', onNeutralC: '#3C4955',
    },
    dark: {
      bg: '#0F1B26', surface: '#162533', surface2: '#1E3040', ink: '#EAF0F4', muted: '#A9B8C4', line: '#2C4052', control: '#6F8497',
      primary: '#7CC4EA', onPrimary: '#06283C', primaryC: '#123F59', onPrimaryC: '#CFE8F6',
      accent: '#E6AC63', accentC: '#43300F', onAccentC: '#F6DDBA',
      success: '#6FCF9D', successC: '#123D2A', onSuccessC: '#C4EFD8',
      warning: '#E9B45C', warningC: '#43300C', onWarningC: '#F7E0B5',
      danger: '#F2A19B', onDanger: '#4A0F0B', dangerC: '#4A1D1A', onDangerC: '#FAD7D3',
      neutralC: '#263A4B', onNeutralC: '#CBD6DE',
    },
  },
  b: {
    slug: 'b-zaytoun', name: 'Zaytoun / Olive and Clay', font: 'readex',
    light: {
      bg: '#F6F1E6', surface: '#FFFDF8', surface2: '#EEE6D5', ink: '#2A2A1E', muted: '#5E5A48', line: '#DDD3BE', control: '#8C8468',
      primary: '#3F5B2B', onPrimary: '#FFFFFF', primaryC: '#E3EBD3', onPrimaryC: '#2C4119',
      accent: '#A8431F', accentC: '#F7E0D3', onAccentC: '#74290F',
      success: '#2F6B3A', successC: '#DDEEDD', onSuccessC: '#1E4A27',
      warning: '#855500', warningC: '#F6E6C2', onWarningC: '#5C3A00',
      danger: '#A82E22', onDanger: '#FFFFFF', dangerC: '#F8DEDA', onDangerC: '#761E15',
      neutralC: '#E7DFCE', onNeutralC: '#4A4737',
    },
  },
  c: {
    slug: 'c-signal', name: 'Nabd / Signal', font: 'alexandria',
    light: {
      bg: '#12101F', surface: '#1C1930', surface2: '#272341', ink: '#F2F0FA', muted: '#B3AECB', line: '#37325A', control: '#7A7499',
      primary: '#C6F04D', onPrimary: '#171A05', primaryC: '#2E3A10', onPrimaryC: '#DDF78F',
      accent: '#FF8A5C', accentC: '#47210F', onAccentC: '#FFD2BF',
      success: '#7BE3A6', successC: '#123B28', onSuccessC: '#C6F3D9',
      warning: '#FFC857', warningC: '#3F2F08', onWarningC: '#FFE7B3',
      danger: '#FF9C94', onDanger: '#3A0E0B', dangerC: '#4A1B1B', onDangerC: '#FFD6D2',
      neutralC: '#2D2950', onNeutralC: '#D6D2E8',
    },
  },
};

// [foreground, background, minimum, what it is]
export const pairs = [
  ['ink', 'bg', 4.5, 'Body text on page'], ['ink', 'surface', 4.5, 'Body text on card'], ['ink', 'surface2', 4.5, 'Body text on raised area'],
  ['muted', 'bg', 4.5, 'Secondary text on page'], ['muted', 'surface', 4.5, 'Secondary text on card'], ['muted', 'surface2', 4.5, 'Secondary text on raised area'],
  ['onPrimary', 'primary', 4.5, 'Primary button label'], ['primary', 'surface', 4.5, 'Primary as link text'], ['primary', 'bg', 4.5, 'Primary link on page'],
  ['onPrimaryC', 'primaryC', 4.5, 'Verified badge / tonal button'],
  ['accent', 'surface', 4.5, 'Accent text'], ['onAccentC', 'accentC', 4.5, 'Accent chip'],
  ['onSuccessC', 'successC', 4.5, 'Status chip: success'], ['onWarningC', 'warningC', 4.5, 'Status chip: warning'],
  ['onDangerC', 'dangerC', 4.5, 'Status chip: danger'], ['onNeutralC', 'neutralC', 4.5, 'Status chip: neutral'],
  ['control', 'surface', 3, 'Input border and checkbox outline'], ['control', 'bg', 3, 'Control outline on page'],
  ['primary', 'surface', 3, 'Focus ring and progress fill'], ['success', 'surface', 3, 'Met-criterion mark'],
  ['danger', 'surface', 4.5, 'Field error text on card'], ['danger', 'bg', 4.5, 'Field error text on page'],
  ['onDanger', 'danger', 4.5, 'Destructive button label'],
  ['warning', 'surface', 3, 'Attention bar on a row'], ['accent', 'bg', 4.5, 'Accent text on page'],
  ['primary', 'bg', 3, 'Focus ring on page'], ['control', 'surface2', 3, 'Control outline on raised area'],
  ['primary', 'surface2', 3, 'Progress fill on its track'],
];

export function luminance(hex) {
  const [r, g, b] = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map(v => (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

export function ratio(a, b) {
  const [x, y] = [luminance(a), luminance(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
}
