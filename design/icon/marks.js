// Icon directions for 一隅, drawn as SVG.
// Badge marks sit on the collapsed badge's 44 × 44 grid (y down, same as the SwiftUI Canvas) and use
// only the skin's colour roles through CSS classes, so every skin can repaint them:
//   fp/fa/fi/fm = fill paper/accent/ink/inkMuted, sa/sp/sm = stroke accent/paper/inkMuted.
// Menu bar marks are 18 × 18 template images: one colour (currentColor), knockouts as masks.
// App icons are 1024 × 1024 with fixed 磁青泥金 colours; the body is the 824 pt macOS icon grid,
// and badge geometry maps onto it with GRID_TO_APP so the three icons share one drawing.

const GRID_TO_APP = 'translate(100 100) scale(18.7273)';
const BODY = 'x="100" y="100" width="824" height="824" rx="185"';
const C = {
  paper: '#1E2B4D', paperDeep: '#16203B', wallTop: '#25345E', night: '#111A30',
  gold: '#C8A96A', goldLight: '#E8D29C', goldDark: '#9A7B45', ink: '#E9E6DC', ivory: '#F6EFD9',
};

let uidCounter = 0;
const uid = (prefix) => `${prefix}${++uidCounter}`;

function blossom(cx, cy, size, cls, turn = -90) {
  const petals = [0, 1, 2, 3, 4].map((i) => {
    const a = (turn + i * 72) * Math.PI / 180;
    const x = (cx + Math.cos(a) * size * 0.6).toFixed(2);
    const y = (cy + Math.sin(a) * size * 0.6).toFixed(2);
    return `<circle cx="${x}" cy="${y}" r="${(size * 0.44).toFixed(2)}"/>`;
  });
  return `<g class="${cls}">${petals.join('')}</g>`;
}

function shadowFilter(id) {
  return `<filter id="${id}" x="-20%" y="-20%" width="140%" height="150%">
    <feGaussianBlur in="SourceAlpha" stdDeviation="14"/><feOffset dy="12"/>
    <feComponentTransfer><feFuncA type="linear" slope="0.32"/></feComponentTransfer>
    <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>`;
}

function appFrame(inner, defs = '') {
  const shadow = uid('sh');
  const clip = uid('body');
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>${shadowFilter(shadow)}<clipPath id="${clip}"><rect ${BODY}/></clipPath>${defs}</defs>
  <rect ${BODY} fill="${C.paperDeep}" filter="url(#${shadow})"/>
  <g clip-path="url(#${clip})">${inner}</g></svg>`;
}

function wall(id, top = C.wallTop, bottom = C.paperDeep) {
  return {
    defs: `<linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${top}"/><stop offset="1" stop-color="${bottom}"/></linearGradient>`,
    fill: `<rect x="0" y="0" width="1024" height="1024" fill="url(#${id})"/>`,
  };
}

function goldGradient(id, angle = 'v') {
  const [x2, y2] = angle === 'v' ? [0, 1] : [1, 1];
  return `<linearGradient id="${id}" x1="0" y1="0" x2="${x2}" y2="${y2}">
    <stop offset="0" stop-color="${C.goldLight}"/><stop offset=".5" stop-color="${C.gold}"/>
    <stop offset="1" stop-color="${C.goldDark}"/></linearGradient>`;
}

// ── 现在：看书的小人儿（current, for comparison） ─────────────────────────────
const current = {
  id: 'current',
  name: '现在',
  concept: '扎发髻、低头看书的小人儿；App 图标是宋体"隅"字，菜单栏是右上角填实的方框。',
  badge: () => `
    <path class="fa" d="M22 23 C15 23.5 11.5 30 11 37 Q22 40.5 33 37 C32.5 30 29 23.5 22 23Z"/>
    <circle class="fa" cx="22" cy="16" r="6.5"/><circle class="fa" cx="22" cy="7.8" r="2.8"/>
    <path class="sp" stroke-width=".9" d="M17.5 8.4 L26.8 6.8"/>
    <path class="sp" stroke-width=".9" stroke-linecap="round" fill="none" d="M18.3 16.6 Q19.6 18 20.9 16.6 M23.1 16.6 Q24.4 18 25.7 16.6"/>
    <path class="fi" d="M22 29.5 Q18 27.6 14.5 28.2 L15.2 33.6 Q18.6 33 22 34.6 Q25.4 33 28.8 33.6 L29.5 28.2 Q26 27.6 22 29.5Z"/>
    <path class="sm" stroke-width=".6" d="M22 29.6 V34.4"/>`,
  menubar: () => `
    <rect x="2.5" y="2.5" width="13" height="13" rx="3.2" fill="none" stroke="currentColor" stroke-width="1.4"/>
    <rect x="9.2" y="9.2" width="4.4" height="4.4" rx="1.2" fill="currentColor" transform="translate(0 -4.8)"/>`,
  app: () => {
    const w = wall(uid('w'), C.paper, C.paperDeep);
    return appFrame(`${w.fill}
      <rect x="144" y="144" width="736" height="736" rx="146" fill="none" stroke="${C.gold}" stroke-opacity=".55" stroke-width="6"/>
      <rect x="742" y="178" width="104" height="104" rx="26" fill="${C.gold}"/>
      <text x="512" y="540" text-anchor="middle" dominant-baseline="central" font-family="Songti SC" font-weight="900" font-size="470" fill="${C.gold}">隅</text>`, w.defs);
  },
};

// ── 月门 ─────────────────────────────────────────────────────────────────────
const MOONGATE = {
  ring: { cx: 22, cy: 22, r: 15 },
  trunk: 'M5 35.2 L11 31.4 L14.6 27.4 L20.4 24.6',
  bough: 'M20.4 24.6 L23.8 20 L31.6 16.2',
  twigs: ['M14.6 27.4 L13.8 23.8', 'M23.8 20 L23.4 17'],
  blossoms: [[13.6, 21.8, 3.2], [23.3, 14.6, 3.6]],
  buds: [[31.9, 15.9, 1.25], [27.6, 18.2, 1]],
  // The App icon is 18× larger, so it gets finer twigs and more flowers on the same branch.
  appTwigs: ['M14.6 27.4 L13.8 23.8', 'M23.8 20 L23.4 17', 'M27.4 18.1 L29.4 21.4', 'M9.2 32.5 L8.4 29.6', 'M17.4 26 L18.8 28.2'],
  appBlossoms: [[13.6, 21.8, 2.6], [23.3, 14.8, 2.9], [29.8, 22.2, 2.2], [8.2, 28.6, 1.9]],
  appBuds: [[31.9, 15.9, .8], [27.6, 18.2, .65], [19.2, 28.8, .6], [16.6, 24, .55], [25.6, 21.4, .55]],
};

const moongate = {
  id: 'moongate',
  name: '月门',
  verdict: '我最推荐：最有意境，也最扣"一方小天地"；小圆标的圆形正好是那扇门。52pt 下梅花略细，但剪影（圆门 + 斜枝）站得住。',
  concept: '园林里的月洞门：墙上开一个圆，门里斜进来一枝梅。小圆标本身就是那扇圆门，门里是一方小天地。',
  badge: () => {
    const m = MOONGATE;
    const band = uid('band');
    return `<defs><clipPath id="${band}"><path clip-rule="evenodd" d="M5 22 a17 17 0 1 0 34 0 a17 17 0 1 0 -34 0Z M9 22 a13 13 0 1 0 26 0 a13 13 0 1 0 -26 0Z"/></clipPath></defs>
    <circle class="fa" cx="22" cy="22" r="${m.ring.r}" fill-opacity=".12"/>
    <circle cx="22" cy="22" r="${m.ring.r}" class="sa" stroke-width="1.5"/>
    <path d="${m.trunk}" class="sp" stroke-width="5" fill="none" stroke-linecap="round" clip-path="url(#${band})"/>
    <path d="${m.trunk}" class="sa" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="${m.bough}" class="sa" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>
    ${m.twigs.map((d) => `<path d="${d}" class="sa" stroke-width="1.1" stroke-linecap="round"/>`).join('')}
    ${m.blossoms.map(([x, y, s]) => blossom(x, y, s, 'fi')).join('')}
    ${m.blossoms.map(([x, y]) => `<circle class="fa" cx="${x}" cy="${y}" r=".75"/>`).join('')}
    ${m.buds.map(([x, y, r]) => `<circle class="fi" cx="${x}" cy="${y}" r="${r}"/>`).join('')}`;
  },
  menubar: () => {
    const mask = uid('m');
    return `<defs><mask id="${mask}"><rect width="18" height="18" fill="#fff"/>
      <circle cx="9" cy="9.3" r=".95" fill="#000"/></mask></defs>
      <path d="M4.6 15.2 A6.8 6.8 0 1 1 13.4 15.2" fill="none" stroke="currentColor" stroke-width="1.35" stroke-linecap="round"/>
      <path d="M1.2 15.2 H16.8" stroke="currentColor" stroke-width="1.35" stroke-linecap="round"/>
      <path d="M9 12.4 Q8.8 14 7.6 15.2" fill="none" stroke="currentColor" stroke-width="1.1" stroke-linecap="round"/>
      <g fill="currentColor" mask="url(#${mask})">${blossom(9, 9.3, 3.7, '').replace('<g class="">', '<g>')}</g>`;
  },
  app: () => {
    const m = MOONGATE;
    const w = wall(uid('w'));
    const moon = uid('moon');
    const rim = uid('rim');
    const open = uid('open');
    const blur = uid('blur');
    const defs = `${w.defs}
      <radialGradient id="${moon}" cx=".4" cy=".36" r=".78">
        <stop offset="0" stop-color="#EEDDAE"/><stop offset=".55" stop-color="${C.gold}"/><stop offset="1" stop-color="#A3854D"/></radialGradient>
      ${goldGradient(rim, 'd')}
      <clipPath id="${open}"><circle cx="512" cy="512" r="281"/></clipPath>
      <filter id="${blur}"><feGaussianBlur stdDeviation="16"/></filter>`;
    return appFrame(`${w.fill}
      <circle cx="512" cy="512" r="281" fill="url(#${moon})"/>
      <g clip-path="url(#${open})"><circle cx="512" cy="484" r="300" fill="none" stroke="#0B1222" stroke-opacity=".5" stroke-width="46" filter="url(#${blur})"/></g>
      <circle cx="512" cy="512" r="287" fill="none" stroke="url(#${rim})" stroke-width="13"/>
      <g transform="${GRID_TO_APP}">
        <path d="${m.trunk}" stroke="${C.night}" stroke-width="1.7" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
        <path d="${m.bough}" stroke="${C.night}" stroke-width="1.1" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
        ${m.appTwigs.map((d) => `<path d="${d}" stroke="${C.night}" stroke-width=".7" stroke-linecap="round"/>`).join('')}
        <g fill="${C.ivory}">${m.appBlossoms.map(([x, y, s], i) => blossom(x, y, s, '', -90 + i * 23)).join('')}</g>
        <g fill="${C.goldDark}">${m.appBlossoms.map(([x, y]) => `<circle cx="${x}" cy="${y}" r=".5"/>`).join('')}</g>
        <g fill="${C.ivory}">${m.appBuds.map(([x, y, r]) => `<circle cx="${x}" cy="${y}" r="${r}"/>`).join('')}</g>
      </g>`, defs);
  },
};

// ── 一灯 ─────────────────────────────────────────────────────────────────────
const LAMP = {
  flame: 'M22 6.6 C23.6 10.3 26 12.6 26 16 C26 18.5 24.2 20.2 22 20.2 C19.8 20.2 18 18.5 18 16 C18 12.6 20.4 10.3 22 6.6Z',
  core: 'M22 13.4 C22.6 15 23.6 15.8 23.6 17.1 C23.6 18.1 22.9 18.8 22 18.8 C21.1 18.8 20.4 18.1 20.4 17.1 C20.4 15.8 21.4 15 22 13.4Z',
  dish: 'M13.2 21.6 H30.8 C30.4 25.1 26.8 27.2 22 27.2 C17.2 27.2 13.6 25.1 13.2 21.6Z',
  wick: 'M21.4 19.6 H22.6 V21.8 H21.4Z',
  stem: 'M21 26.8 H23 L23.3 29.2 C24.7 29.6 24.7 30.8 23.3 31.2 L23.7 33.4 H20.3 L20.7 31.2 C19.3 30.8 19.3 29.6 20.7 29.2Z',
  foot: 'M15.2 36 C15.9 34.1 18.5 33.2 22 33.2 C25.5 33.2 28.1 34.1 28.8 36 Q29 36.6 28.4 36.6 H15.6 Q15 36.6 15.2 36Z',
};

const lamp = {
  id: 'lamp',
  name: '一灯',
  verdict: '剪影最清楚，16px 也认得出，气质温暖；缺点是灯盏在别处也常见，园林味不如月门。',
  concept: '"照千一隅，此则国宝"：点一盏小灯，照亮自己的一个角落。灯盏剪影简单，缩到很小也认得出。',
  badge: () => {
    const g = uid('glow');
    const l = LAMP;
    return `<defs><radialGradient id="${g}"><stop offset="0" class="stop-accent" stop-opacity=".42"/>
      <stop offset="1" class="stop-accent" stop-opacity="0"/></radialGradient></defs>
    <circle cx="22" cy="16" r="11" fill="url(#${g})"/>
    <path class="fa" d="${l.flame}"/><path class="fp" d="${l.core}"/>
    <path class="fa" d="${l.wick}"/><path class="fa" d="${l.dish}"/>
    <path class="fa" d="${l.stem}"/><path class="fa" d="${l.foot}"/>`;
  },
  menubar: () => `
    <path fill="currentColor" d="M9 1 C9.9 3.1 11.3 4.4 11.3 6.4 C11.3 7.8 10.3 8.8 9 8.8 C7.7 8.8 6.7 7.8 6.7 6.4 C6.7 4.4 8.1 3.1 9 1Z"/>
    <path fill="currentColor" d="M3.8 9.8 H14.2 C14 11.9 11.8 13.1 9 13.1 C6.2 13.1 4 11.9 3.8 9.8Z"/>
    <path fill="currentColor" d="M8.3 12.8 H9.7 L9.9 13.9 C10.7 14.1 10.7 14.7 9.9 14.9 L10.1 15.6 H7.9 L8.1 14.9 C7.3 14.7 7.3 14.1 8.1 13.9Z"/>
    <path fill="currentColor" d="M5.4 17 C5.8 15.9 7.2 15.4 9 15.4 C10.8 15.4 12.2 15.9 12.6 17Z"/>`,
  app: () => {
    const w = wall(uid('w'), '#22305A', '#121A31');
    const glow = uid('glow');
    const metal = uid('metal');
    const fire = uid('fire');
    const pool = uid('pool');
    const l = LAMP;
    const defs = `${w.defs}
      <radialGradient id="${glow}" cx="512" cy="400" r="420" gradientUnits="userSpaceOnUse">
        <stop offset="0" stop-color="${C.gold}" stop-opacity=".62"/><stop offset=".35" stop-color="${C.gold}" stop-opacity=".2"/>
        <stop offset="1" stop-color="${C.gold}" stop-opacity="0"/></radialGradient>
      ${goldGradient(metal)}
      <radialGradient id="${fire}" cx=".5" cy=".78" r=".75">
        <stop offset="0" stop-color="#FFFBEF"/><stop offset=".45" stop-color="#F5E2B0"/><stop offset="1" stop-color="#D9B26A"/></radialGradient>
      <radialGradient id="${pool}" cx="512" cy="790" r="200" gradientUnits="userSpaceOnUse">
        <stop offset="0" stop-color="#000" stop-opacity=".38"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>`;
    return appFrame(`${w.fill}
      <rect x="0" y="0" width="1024" height="1024" fill="url(#${glow})"/>
      <ellipse cx="512" cy="790" rx="230" ry="40" fill="url(#${pool})"/>
      <g transform="${GRID_TO_APP}">
        <path fill="url(#${metal})" d="${l.wick}"/>
        <path fill="url(#${metal})" d="${l.dish}"/><path fill="url(#${metal})" d="${l.stem}"/><path fill="url(#${metal})" d="${l.foot}"/>
        <path fill="${C.goldLight}" fill-opacity=".55" d="M13.6 21.6 H30.4 C30.2 22.3 29.8 22.8 29.2 23.2 H14.8 C14.2 22.8 13.8 22.3 13.6 21.6Z"/>
        <path fill="url(#${fire})" d="${l.flame}"/>
      </g>`, defs);
  },
};

// ── 折角 ─────────────────────────────────────────────────────────────────────
const dogear = {
  id: 'dogear',
  name: '折角',
  verdict: 'App 图标最克制、最高级；但小圆标和菜单栏容易被看成普通文件图标，适合只拿来做 App 图标。',
  concept: '书页右上角折起的一角：读到哪儿、记到哪儿，就在角落里折个记号。页上是写经的金丝界栏。',
  badge: () => `
    <path class="fa" fill-opacity=".16" d="M10.5 12.4 Q10.5 10 12.9 10 H26 L34 18 V31.6 Q34 34 31.6 34 H12.9 Q10.5 34 10.5 31.6Z"/>
    <path class="sa" stroke-width="1.4" stroke-linecap="round" d="M27.6 21.4 V24.6 M27.6 26.6 V29.8 M22.2 14.2 V19.6 M22.2 21.6 V24.2 M22.2 26.2 V29.8 M16.8 14.2 V17 M16.8 19 V24.6"/>
    <path class="fa" stroke-linejoin="round" d="M26 10 V16 Q26 18 28 18 H34Z"/>`,
  menubar: () => `
    <path d="M2.5 5.4 Q2.5 2.5 5.4 2.5 H10.6 L15.5 7.4 V12.6 Q15.5 15.5 12.6 15.5 H5.4 Q2.5 15.5 2.5 12.6Z" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"/>
    <path d="M10.6 2.5 V6.2 Q10.6 7.4 11.8 7.4 H15.5Z" fill="currentColor" stroke="currentColor" stroke-width=".8" stroke-linejoin="round"/>`,
  app: () => {
    const page = uid('page');
    const flap = uid('flap');
    const pageClip = uid('pc');
    const flapShadow = uid('fs');
    const fold = 300;
    const pagePath = `M285 100 H${924 - fold} L924 ${100 + fold} V739 A185 185 0 0 1 739 924 H285 A185 185 0 0 1 100 739 V285 A185 185 0 0 1 285 100Z`;
    const rules = [282, 374, 466, 558, 650, 742].map((x) => `M${x} 196 V828`).join(' ');
    const defs = `<linearGradient id="${page}" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${C.wallTop}"/><stop offset="1" stop-color="${C.paperDeep}"/></linearGradient>
      <linearGradient id="${flap}" x1="${924 - fold}" y1="100" x2="${924 - fold}" y2="${100 + fold}" gradientUnits="userSpaceOnUse">
        <stop offset="0" stop-color="${C.goldDark}"/><stop offset=".55" stop-color="${C.gold}"/><stop offset="1" stop-color="${C.goldLight}"/></linearGradient>
      <clipPath id="${pageClip}"><path d="${pagePath}"/></clipPath>
      <filter id="${flapShadow}" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur in="SourceAlpha" stdDeviation="18"/>
        <feOffset dx="-14" dy="18"/><feComponentTransfer><feFuncA type="linear" slope=".55"/></feComponentTransfer>
        <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>`;
    return appFrame(`<rect x="0" y="0" width="1024" height="1024" fill="${C.night}"/>
      <path d="${pagePath}" fill="url(#${page})"/>
      <g clip-path="url(#${pageClip})" stroke="${C.gold}">
        <rect x="190" y="196" width="644" height="632" fill="none" stroke-opacity=".6" stroke-width="7"/>
        <path d="${rules}" stroke-opacity=".38" stroke-width="3.5"/>
      </g>
      <path filter="url(#${flapShadow})" fill="url(#${flap})" d="M${924 - fold} 100 L924 ${100 + fold} H${924 - fold + 46} Q${924 - fold} ${100 + fold} ${924 - fold} ${100 + fold - 46}Z"/>`, defs);
  },
};

// ── 隅印 ─────────────────────────────────────────────────────────────────────
const SEAL_FONT = `font-family="Weibei SC, STKaiti, Songti SC" font-weight="700"`;
const SEAL_CHIPS = [[9.6, 15.4, .9], [20.4, 9.4, .75], [34.5, 27.8, .95], [27.4, 34.6, .7], [9.5, 30.2, .6]];

const seal = {
  id: 'seal',
  name: '隅印',
  verdict: '最稳妥，延续现在的"隅"字，在哪种皮肤上都醒目；但最像一个 logo，故事性弱一点。',
  concept: '把"隅"字刻成一方闲章，像文人在画角钤的那一方小印。白文镂空、破边，方寸之间就是一隅。',
  badge: () => `
    <g transform="rotate(-4 22 22)">
      <rect class="fa" x="9.4" y="9.4" width="25.2" height="25.2" rx="2.4"/>
      <rect class="sp" x="11.3" y="11.3" width="21.4" height="21.4" rx="1.2" fill="none" stroke-width=".7"/>
      <text class="fp" x="22" y="23.2" text-anchor="middle" dominant-baseline="central" ${SEAL_FONT} font-size="19">隅</text>
      ${SEAL_CHIPS.map(([x, y, r]) => `<circle class="fp" cx="${x}" cy="${y}" r="${r}"/>`).join('')}
    </g>`,
  menubar: () => {
    const mask = uid('m');
    return `<defs><mask id="${mask}"><rect width="18" height="18" fill="#fff"/>
      <text x="9" y="9.6" text-anchor="middle" dominant-baseline="central" ${SEAL_FONT} font-size="11.5" fill="#000">隅</text></mask></defs>
      <rect x="2" y="2" width="14" height="14" rx="2.4" fill="currentColor" mask="url(#${mask})"/>`;
  },
  app: () => {
    const w = wall(uid('w'));
    const metal = uid('metal');
    const mask = uid('m');
    const grain = uid('g');
    const defs = `${w.defs}${goldGradient(metal, 'd')}
      <filter id="${grain}"><feTurbulence type="fractalNoise" baseFrequency=".9" numOctaves="2" seed="7"/>
        <feColorMatrix values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -2.2 1.35"/><feComposite in2="SourceGraphic" operator="in"/></filter>
      <mask id="${mask}"><rect width="1024" height="1024" fill="#fff"/>
        <g transform="${GRID_TO_APP} rotate(-4 22 22)">
          <rect x="11.3" y="11.3" width="21.4" height="21.4" rx="1.2" fill="none" stroke="#000" stroke-width=".7"/>
          <text x="22" y="23.2" text-anchor="middle" dominant-baseline="central" ${SEAL_FONT} font-size="19" fill="#000">隅</text>
          ${SEAL_CHIPS.map(([x, y, r]) => `<circle cx="${x}" cy="${y}" r="${r}" fill="#000"/>`).join('')}
        </g></mask>`;
    return appFrame(`${w.fill}
      <g mask="url(#${mask})"><g transform="${GRID_TO_APP} rotate(-4 22 22)">
        <rect x="9.4" y="9.4" width="25.2" height="25.2" rx="2.4" fill="url(#${metal})"/>
        <rect x="9.4" y="9.4" width="25.2" height="25.2" rx="2.4" fill="${C.paperDeep}" filter="url(#${grain})" opacity=".22"/>
      </g></g>`, defs);
  },
};

// ── 一角 ─────────────────────────────────────────────────────────────────────
const CORNER = {
  cliff: 'M-4 50 V26 L3 24.6 L6.8 20.4 L10.6 20.8 L13 16.6 L16.4 15.8 L18.6 18.8 L17.6 22.6 L21.6 25.6 L23 30 L27.4 35.2 L30 50Z',
  // The face turned away from the moon, a little darker.
  shade: 'M-4 50 V26 L3 24.6 L6.8 20.4 L10.6 20.8 L13 16.6 L14.4 22.2 L11.6 27.4 L14.2 33.4 L11.4 50Z',
  trunk: 'M15.6 16.4 C16.2 13.2 18.8 11.4 22.6 11.6 C25.8 11.8 28.6 13.2 31 15.4',
  limb: 'M24.6 11.8 C25.4 13.4 26.4 14.8 27.8 15.8',
  pads: [[19.2, 11.1, 3.3, .72], [25.2, 11.2, 3.8, .78], [30.2, 14.4, 3.3, .72], [27.4, 16.6, 2.6, .66]],
  moon: [32.6, 24.2, 3.1],
};

const corner = {
  id: 'corner',
  name: '一角',
  verdict: '大图最有画意（看 Codex 质感稿）；代码画的版本还要细化，小尺寸下松树不好认。',
  concept: '南宋马远的"马一角"：山只画在一角，其余留白，一角就是一方天地。崖石从小圆标的角上探进来，松枝伸向月亮。',
  badge: () => {
    const k = CORNER;
    const [mx, my, mr] = k.moon;
    return `
    <path class="fa" d="${k.cliff}"/>
    <path class="fp" fill-opacity=".22" d="${k.shade}"/>
    <path class="sa" stroke-width="1.35" stroke-linecap="round" d="${k.trunk}"/>
    <path class="sa" stroke-width=".9" stroke-linecap="round" d="${k.limb}"/>
    ${k.pads.map(([x, y, rx, ry]) => `<ellipse class="fa" cx="${x}" cy="${y}" rx="${rx}" ry="${ry}"/>`).join('')}
    <circle class="fi" cx="${mx}" cy="${my}" r="${mr}"/>`;
  },
  menubar: () => `
    <path fill="currentColor" d="M.5 17.5 V9.4 L3.4 8 L5.6 5.2 L7.8 6.8 L7.4 9.6 L10.2 11.8 L11.6 17.5Z"/>
    <path fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" d="M5.6 5.4 C6.6 3.8 8.6 3.2 10.8 3.6 C12.2 3.9 13.2 4.6 14 5.6"/>
    <ellipse cx="9.6" cy="3.3" rx="2.4" ry=".7" fill="currentColor"/><ellipse cx="13.4" cy="5.2" rx="2" ry=".65" fill="currentColor"/>
    <circle cx="14.6" cy="12" r="1.9" fill="currentColor"/>`,
  app: () => {
    const k = CORNER;
    const [mx, my, mr] = k.moon;
    const w = wall(uid('w'));
    const metal = uid('metal');
    const halo = uid('halo');
    const defs = `${w.defs}${goldGradient(metal, 'd')}
      <radialGradient id="${halo}" cx="${100 + mx * 18.7273}" cy="${100 + my * 18.7273}" r="230" gradientUnits="userSpaceOnUse">
        <stop offset="0" stop-color="${C.ink}" stop-opacity=".3"/><stop offset="1" stop-color="${C.ink}" stop-opacity="0"/></radialGradient>`;
    return appFrame(`${w.fill}
      <rect x="0" y="0" width="1024" height="1024" fill="url(#${halo})"/>
      <g transform="${GRID_TO_APP}">
        <path fill="url(#${metal})" d="${k.cliff}"/>
        <path fill="${C.paperDeep}" fill-opacity=".28" d="${k.shade}"/>
        <path stroke="${C.gold}" stroke-width="1.2" stroke-linecap="round" fill="none" d="${k.trunk}"/>
        <path stroke="${C.gold}" stroke-width=".8" stroke-linecap="round" fill="none" d="${k.limb}"/>
        <g fill="${C.gold}">${k.pads.map(([x, y, rx, ry]) => `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}"/>`).join('')}</g>
        <circle cx="${mx}" cy="${my}" r="${mr}" fill="${C.ink}"/>
      </g>`, defs);
  },
};

window.ICON_DIRECTIONS = [moongate, lamp, dogear, seal, corner];
window.ICON_CURRENT = current;
window.iconUid = uid;
