// DOSSEDART — Home (arcade) · dagens design, modus-rutenett → 3×3
// ───────────────────────────────────────────────────────────────
// Dette ER dagens startside (home-arcade-overhaul): INSERT COIN-header,
// DOSSE DART-wordmark, HIGH SCORES-podium, X01-rad (301/501/701) og
// footer — ALT uendret. Den ENESTE endringen: «OR PICK A LEVEL»-
// rutenettet går fra 2 kolonner til 3×3 med emoji-symbolene, så Gotcha
// (ny) + Legs/Golf (coming soon) får plass. Ingenting annet er rørt.

const AW = 820, AH = 1180;

const YELLOW   = '#FFD200';
const SILVER   = '#D9D2C2';
const BRONZE   = '#CD7F32';
const PHOSPHOR = '#D9D2C2';
const CYAN     = '#00E5FF';
const MAGENTA  = '#FF00AA';
const GREEN    = '#3DFF8E';
const RED      = '#FF3050';
const BG       = '#0a0014';
const SURFACE  = '#1a0030';

const TOP = [
  { handle:'AND', name:'Andreas', rating: 1568, w: 89, photo:['#F26A1B','#D14B2A'] },
  { handle:'JON', name:'Jonas',   rating: 1422, w: 51, photo:['#1B7AA8','#3A6B8A'] },
  { handle:'MIA', name:'Mia',     rating: 1387, w: 38, photo:['#7A4FB0','#9C27B0'] },
];
const X01 = [
  { n:301, em:'🥉', tag:'short'   },
  { n:501, em:'🍻', tag:'classic' },
  { n:701, em:'🏆', tag:'long'    },
];
// 3×3 — 5 live modes + Gotcha (ny) + Legs/Golf/generic (coming soon).
// Rekkefølge fra spec §4.1.
const GRID = [
  { k:'cricket',  label:'Cricket',          em:'🎯', st:'live' },
  { k:'atc',      label:'Around the Clock', em:'🕒', st:'live' },
  { k:'killer',   label:'Killer',           em:'🔪', st:'live' },
  { k:'split',    label:'Splitscore',       em:'✂️', st:'live' },
  { k:'shanghai', label:'Shanghai',         em:'🐉', st:'live' },
  { k:'gotcha',   label:'Gotcha',           em:'💀', st:'new'  },
  { k:'legs',     label:'Legs',             em:'🦵', st:'soon' },
  { k:'golf',     label:'Golf',             em:'⛳', st:'soon' },
  { k:'more',     label:'Coming soon',      em:'✨', st:'soon2'},
];

// ─── Header / Footer ─────────────────────────────────────────── (uendret)
const Header = () => (
  <div style={{padding:'22px 28px 18px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, textAlign:'center', position:'relative', zIndex:6}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:4}}>★ ★ ★  INSERT COIN  ★ ★ ★</div>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:36, color:YELLOW, textShadow:`0 0 10px ${YELLOW}, 4px 4px 0 ${MAGENTA}`, marginTop:14, letterSpacing:1, lineHeight:1.3}}>DOSSE<br/>DART</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:20, color:PHOSPHOR, marginTop:10, letterSpacing:2}}>©2024 OFFICE GAMES INC.</div>
  </div>
);

const CabBtn = ({ label, sub, icon }) => (
  <div style={{flex:1, padding:'14px 12px', background:BG, borderTop:`3px solid ${CYAN}`, position:'relative', display:'flex', flexDirection:'column', alignItems:'center', gap:6}}>
    <div style={{position:'absolute', top:-8, left:'50%', transform:'translateX(-50%)', width:18, height:8, borderRadius:'4px 4px 0 0', background:CYAN, boxShadow:`0 0 6px ${CYAN}`}}/>
    <div style={{fontSize:22, lineHeight:1}}>{icon}</div>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:CYAN, letterSpacing:1, textShadow:`0 0 6px ${CYAN}88`}}>{label}</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>{sub}</div>
  </div>
);

const Footer = () => (
  <div style={{display:'flex', alignItems:'stretch', borderTop:`2px solid ${YELLOW}`, background:'#000', position:'relative', zIndex:6}}>
    <div style={{position:'absolute', top:-2, left:0, right:0, height:2, background:`linear-gradient(90deg, ${MAGENTA} 0%, ${YELLOW} 50%, ${CYAN} 100%)`}}/>
    <CabBtn label="STATS"    sub="P-1" icon="📊"/>
    <CabBtn label="HISTORY"  sub="LOG" icon="📜"/>
    <CabBtn label="SETTINGS" sub="CFG" icon="⚙"/>
  </div>
);

// ─── Photo avatar + podium ───────────────────────────────────── (uendret)
const PhotoAvatar = ({ p, size=46, ring, glow }) => (
  <div style={{width:size, height:size, borderRadius:'50%', border:`${size >= 60 ? 4 : size >= 36 ? 3 : 2}px solid ${ring}`,
    background: p.photo ? `linear-gradient(135deg, ${p.photo[0]} 0%, ${p.photo[1]} 100%)` : SURFACE,
    boxShadow: glow ? `0 0 ${Math.round(size/3)}px ${ring}aa` : `0 0 8px ${ring}55`,
    display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0, position:'relative', overflow:'hidden'}}>
    <div style={{position:'absolute', inset:0, backgroundImage:'repeating-linear-gradient(0deg, transparent 0px, transparent 2px, rgba(0,0,0,0.18) 3px, transparent 4px)', pointerEvents:'none'}}/>
    <div style={{fontFamily:'"VT323", monospace', fontSize: Math.round(size*0.55), color:'rgba(255,255,255,0.95)', textShadow:'0 2px 6px rgba(0,0,0,0.55)', fontWeight:700, lineHeight:1, zIndex:1}}>{p.name[0]}</div>
  </div>
);

const PodiumBlock = ({ p, rank, color, height, crown, avatar=58 }) => (
  <div style={{display:'flex', flexDirection:'column', alignItems:'center', gap:6}}>
    {crown ? <div style={{fontSize:34, lineHeight:1, filter:`drop-shadow(0 0 8px ${color})`}}>👑</div> : <div style={{height:34}}/>}
    <div style={{padding:'4px 10px', background:color, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:11, letterSpacing:1, boxShadow:`0 0 10px ${color}`}}>{rank}</div>
    <div style={{width:'100%', height, background:SURFACE, border:`3px solid ${color}`, boxShadow:`0 0 16px ${color}66, inset 0 0 24px ${color}22`, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', position:'relative', padding:'10px 6px', gap:6}}>
      <div style={{position:'absolute', top:6, left:8, fontFamily:'"VT323", monospace', fontSize:14, color, opacity:.7}}>★</div>
      <div style={{position:'absolute', top:6, right:8, fontFamily:'"VT323", monospace', fontSize:14, color, opacity:.7}}>★</div>
      <div style={{position:'absolute', bottom:6, left:8, fontFamily:'"VT323", monospace', fontSize:14, color, opacity:.7}}>★</div>
      <div style={{position:'absolute', bottom:6, right:8, fontFamily:'"VT323", monospace', fontSize:14, color, opacity:.7}}>★</div>
      <PhotoAvatar p={p} size={avatar} ring={color} glow={crown}/>
      <div style={{fontFamily:'"VT323", monospace', fontSize:crown?24:20, color:'#fff', lineHeight:1, marginTop:2}}>{p.rating}</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:12, color:'#fff', opacity:.55, letterSpacing:1}}>W{p.w}%</div>
    </div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.7)', letterSpacing:2, marginTop:2}}>{p.name.toUpperCase()}</div>
  </div>
);

const Leaderboard = () => (
  <div style={{padding:'16px 28px 10px', borderBottom:`1px dashed ${MAGENTA}66`, position:'relative', zIndex:6}}>
    <div style={{display:'flex', alignItems:'center', justifyContent:'center', gap:14, marginBottom:4}}>
      <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:MAGENTA}}>━━━━</div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:CYAN, letterSpacing:1.5}}>★ HIGH SCORES ★</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:MAGENTA}}>━━━━</div>
    </div>
    <div style={{display:'grid', gridTemplateColumns:'1fr 1.05fr 1fr', gap:10, alignItems:'flex-end', marginTop:8}}>
      <PodiumBlock p={TOP[1]} rank="2ND" color={SILVER} height={118} avatar={50}/>
      <PodiumBlock p={TOP[0]} rank="1ST" color={YELLOW} height={158} crown avatar={64}/>
      <PodiumBlock p={TOP[2]} rank="3RD" color={BRONZE} height={100} avatar={46}/>
    </div>
    <div style={{textAlign:'center', fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.55)', marginTop:8, letterSpacing:2}}>▼ FULL RANKING ▼</div>
  </div>
);

// ─── X01 row ─────────────────────────────────────────────────── (uendret)
const X01Block = () => (
  <div style={{padding:'14px 28px 0', position:'relative', zIndex:6}}>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, marginBottom:10, letterSpacing:1}}>► PLAYER 1 SELECT</div>
    <div style={{display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:10}}>
      {X01.map((r, i) => {
        const hero = i===1;
        const c = hero ? YELLOW : PHOSPHOR;
        return (
          <div key={r.n} style={{padding:'12px 10px', background:SURFACE, border:`3px solid ${c}`, boxShadow:`0 0 16px ${c}55, inset 0 0 16px ${c}22`, textAlign:'center'}}>
            <div style={{fontSize:24, marginBottom:4}}>{r.em}</div>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:24, color:c, letterSpacing:1, textShadow:`0 0 8px ${c}aa`}}>{r.n}</div>
            <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'#fff', opacity:.7, marginTop:4}}>{r.tag.toUpperCase()}</div>
          </div>
        );
      })}
    </div>
  </div>
);

// ─── Mode grid — DEN ENESTE ENDRINGEN: 2 kolonner → 3×3 ─────────
const ModeTile = ({ m }) => {
  const soon = m.st==='soon' || m.st==='soon2';
  const isNew = m.st==='new';
  const c = isNew ? CYAN : PHOSPHOR;
  return (
    <div style={{boxSizing:'border-box', padding:'10px 8px', position:'relative',
      background: isNew ? `${CYAN}10` : soon ? 'transparent' : SURFACE,
      border: soon ? `2px dashed ${MAGENTA}55` : `2px solid ${c}`,
      boxShadow: isNew ? `0 0 16px ${CYAN}66, inset 0 0 14px ${CYAN}22` : soon ? 'none' : `0 0 8px ${PHOSPHOR}33`,
      display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:6, opacity: soon ? 0.55 : 1}}>
      {isNew && <div style={{position:'absolute', top:-9, right:-6, padding:'3px 7px', background:YELLOW, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:8, letterSpacing:1, boxShadow:`0 0 8px ${YELLOW}`, transform:'rotate(5deg)'}}>NEW</div>}
      <div style={{fontSize: m.st==='soon2' ? 24 : 28, lineHeight:1, filter: isNew ? `drop-shadow(0 0 6px ${CYAN})` : 'none', opacity: soon ? 0.7 : 1}}>{m.em}</div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color: isNew ? CYAN : '#fff', letterSpacing:.5, lineHeight:1.35, textAlign:'center', textShadow: isNew ? `0 0 6px ${CYAN}88` : 'none'}}>{m.label.toUpperCase()}</div>
      {soon && <div style={{fontFamily:'"VT323", monospace', fontSize:12, color:'rgba(255,255,255,0.5)', letterSpacing:1.5}}>{m.st==='soon2' ? 'SNART FLERE' : 'COMING SOON'}</div>}
    </div>
  );
};

const ModesBlock = () => (
  <div style={{padding:'14px 28px 16px', flex:1, minHeight:0, position:'relative', zIndex:6}}>
    <div style={{display:'flex', alignItems:'center', gap:10, marginBottom:10}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, letterSpacing:1}}>► OR PICK A LEVEL</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:YELLOW, letterSpacing:1}}>NY: GOTCHA 💀</div>
    </div>
    <div style={{display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gridTemplateRows:'repeat(3, 1fr)', gap:10, height:'calc(100% - 34px)'}}>
      {GRID.map(m => <ModeTile key={m.k} m={m}/>)}
    </div>
  </div>
);

// ─── Shell — struktur identisk med dagens design ────────────────
const HomeShell = () => {
  const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
  return (
    <div style={{width:AW, height:AH, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
      <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}/>
      <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 50%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}/>
      <Header/>
      <Leaderboard/>
      <X01Block/>
      <ModesBlock/>
      <Footer/>
    </div>
  );
};

// ─── spec ───────────────────────────────────────────────────────
const SpecRow = ({ zone, val, hex }) => (
  <div style={{display:'flex', alignItems:'center', gap:10, padding:'7px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
    {hex && <div style={{width:14, height:14, background:hex, border:'1px solid rgba(0,0,0,0.25)', flexShrink:0}}/>}
    <div style={{flex:1, fontFamily:'"Inter", system-ui, sans-serif', fontSize:13, fontWeight:600, color:'#2a251f'}}>{zone}</div>
    <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:12, color:'#5a544a'}}>{val}</div>
  </div>
);
const SpecCard = () => (
  <div style={{boxSizing:'border-box', width:680, height:1180, background:'#fffdf6', border:'1.5px solid rgba(0,0,0,0.14)', padding:'30px 34px', fontFamily:'"Inter", system-ui, sans-serif', display:'flex', flexDirection:'column', gap:15, overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>Startside · minimal endring</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:26, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Dagens hjem — kun rutenettet blir 3×3</div>
    </div>
    <div style={{padding:'12px 14px', background:'#dcefe1', border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a4a36', marginBottom:4}}>Uendret</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#2a4a36', lineHeight:1.5}}>INSERT COIN-header, DOSSE DART-wordmark, ©-linje, HIGH SCORES-podium, X01-raden (301/501/701) og footer (STATS · HISTORY · SETTINGS) er <b>helt like som i dag</b> — samme chrome, samme emoji, samme farger.</div>
    </div>
    <div style={{padding:'12px 14px', background:'#fbe9d8', border:'1px solid rgba(201,100,66,0.35)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#8a3d1a', marginBottom:4}}>Endret</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a442f', lineHeight:1.5}}>«OR PICK A LEVEL»-rutenettet går fra <b>2 kolonner</b> til <b>3×3</b>. Samme flis-stil, bare tre per rad — plass til Gotcha (ny) og Legs/Golf (coming soon).</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Rutenett 3×3 (spec §4.1)</div>
      <SpecRow zone="Rad 1 — 🎯 Cricket · 🕒 Clock · 🔪 Killer" val="live" hex={PHOSPHOR}/>
      <SpecRow zone="Rad 2 — ✂️ Splitscore · 🐉 Shanghai · 💀 Gotcha" val="+ ny" hex={CYAN}/>
      <SpecRow zone="Rad 3 — 🦵 Legs · ⛳ Golf · ✨ generisk" val="coming soon" hex={MAGENTA}/>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:8, textTransform:'uppercase', letterSpacing:0.5}}>Flis-tilstander</div>
      {[
        ['Live','Uendret flis: SURFACE-bg, phosphor ramme, emoji + navn.'],
        ['Ny (Gotcha)','Cyan ramme + glow + gult NEW-bånd. GameMode.gotcha lagt til nå.'],
        ['Coming soon','Dimmet (0.55), stiplet ramme, «COMING SOON». Legs/Golf + generisk celle er hardkodede placeholder-fliser til modusene finnes — ingen døde enum-verdier. Lyser opp når de slippes.'],
      ].map(([t,b])=>(
        <div key={t} style={{padding:'8px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
          <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, fontWeight:700, color:'#2a251f'}}>{t}</div>
          <div style={{fontFamily:'"Inter", sans-serif', fontSize:11.5, lineHeight:1.45, color:'#5a544a', marginTop:2}}>{b}</div>
        </div>
      ))}
    </div>
    <div style={{marginTop:'auto', padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, lineHeight:1.55, color:'#5a544a'}}>
        Podium-høydene er trimmet minimalt (1ST 158 vs 200) kun for å gi den tredje rad-en plass innenfor samme skjerm — ingen andre endringer.
      </div>
    </div>
  </div>
);

// ── Canvas ──────────────────────────────────────────────────────
const HomeGotcha3x3 = () => (
  <DCSection
    id="home-3x3"
    title="Startside — dagens design, rutenett → 3×3"
    subtitle="Dette ER dagens arkade-hjem: INSERT COIN, DOSSE DART, HIGH SCORES-podium, X01-raden (301/501/701) og footer — alt uendret. Den eneste endringen er «OR PICK A LEVEL»-rutenettet: 2 kolonner → 3×3 med de samme emoji-symbolene, så Gotcha (ny) og Legs/Golf (coming soon) får plass.">
    <DCArtboard id="h3-screen" label="Hjem · rutenett 3×3 med Gotcha" width={AW} height={AH}><HomeShell/></DCArtboard>
    <DCArtboard id="h3-spec" label="Hva som er endret · spec" width={680} height={1180}><SpecCard/></DCArtboard>
  </DCSection>
);
window.HomeGotcha3x3 = HomeGotcha3x3;
window.HomeGotcha3x3Shell = HomeShell;
