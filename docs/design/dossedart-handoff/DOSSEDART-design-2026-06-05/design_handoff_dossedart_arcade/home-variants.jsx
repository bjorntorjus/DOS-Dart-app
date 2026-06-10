// DOSSEDART — Home variants (today's design, initials removed)
// Faithful copy of home-arcade-overhaul (TODAY) — same layout, podium, emoji,
// modes, X01 row, footer. ONLY the avatar changes, gated on window.AV_MODE:
//   'glyph' = neutral person silhouette (no photos, uniform)
//   'photo' = player photo (per-player gradient stand-in + white silhouette)
// Loaded alone per raw page (no const collisions with the original).

const AW = 820, AH = 1180;
const YELLOW='#FFD200', SILVER='#D9D2C2', BRONZE='#CD7F32', PHOSPHOR='#D9D2C2',
      CYAN='#00E5FF', MAGENTA='#FF00AA', BG='#0a0014', SURFACE='#1a0030';

const TOP = [
  { handle:'AND', name:'Andreas', rating:1568, w:89, photo:['#F26A1B','#D14B2A'] },
  { handle:'JON', name:'Jonas',   rating:1422, w:51, photo:['#1B7AA8','#3A6B8A'] },
  { handle:'MIA', name:'Mia',     rating:1387, w:38, photo:null },
];
const MODES = [
  { k:'cricket', label:'Cricket', em:'🎯' },
  { k:'atc', label:'Around the Clock', em:'🕒' },
  { k:'killer', label:'Killer', em:'🔪' },
  { k:'halve', label:'Halve It', em:'✂️' },
  { k:'shanghai', label:'Shanghai', em:'🐉' },
];
const X01 = [ { n:301, em:'🥉', tag:'short' }, { n:501, em:'🍻', tag:'classic' }, { n:701, em:'🏆', tag:'long' } ];

const Header = () => (
  <div style={{padding:'22px 28px 18px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, textAlign:'center'}}>
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
  <div style={{display:'flex', alignItems:'stretch', borderTop:`2px solid ${YELLOW}`, background:'#000', position:'relative'}}>
    <div style={{position:'absolute', top:-2, left:0, right:0, height:2, background:`linear-gradient(90deg, ${MAGENTA} 0%, ${YELLOW} 50%, ${CYAN} 100%)`}}/>
    <CabBtn label="STATS" sub="P-1" icon="📊"/>
    <CabBtn label="HISTORY" sub="LOG" icon="📜"/>
    <CabBtn label="SETTINGS" sub="CFG" icon="⚙"/>
  </div>
);

// ONLY change vs today: no initial letter — neutral glyph OR photo silhouette
const PhotoAvatar = ({ p, size=46, ring, glow }) => {
  const photo = !!p.photo;  // real photo if the player has one, else neutral silhouette
  return (
    <div style={{width:size, height:size, borderRadius:'50%',
      border:`${size>=60?4:size>=36?3:2}px solid ${ring}`,
      background: photo ? `linear-gradient(135deg, ${p.photo[0]} 0%, ${p.photo[1]} 100%)` : '#1a0030',
      boxShadow: glow ? `0 0 ${Math.round(size/3)}px ${ring}aa` : `0 0 8px ${ring}55`,
      display:'flex', alignItems:'flex-end', justifyContent:'center', flexShrink:0, position:'relative', overflow:'hidden'}}>
      <div style={{position:'absolute', inset:0, backgroundImage:'repeating-linear-gradient(0deg, transparent 0px, transparent 2px, rgba(0,0,0,0.18) 3px, transparent 4px)', pointerEvents:'none'}}/>
      <svg width={size*0.82} height={size*0.82} viewBox="0 0 24 24" style={{marginBottom:-1, position:'relative', zIndex:1}}>
        <circle cx="12" cy="9" r="4.3" fill={photo?'rgba(255,255,255,0.94)':ring} opacity="0.95"/>
        <path d="M3.5 22c0-5 3.8-8 8.5-8s8.5 3 8.5 8z" fill={photo?'rgba(255,255,255,0.94)':ring} opacity="0.95"/>
      </svg>
    </div>
  );
};
const PodiumBlock = ({ p, rank, color, height, crown, avatar=58 }) => (
  <div style={{display:'flex', flexDirection:'column', alignItems:'center', gap:6}}>
    {crown ? <div style={{fontSize:34, lineHeight:1, filter:`drop-shadow(0 0 8px ${color})`}}>👑</div> : <div style={{height:34}}/>}
    <div style={{padding:'4px 10px', background:color, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:11, letterSpacing:1, boxShadow:`0 0 10px ${color}`}}>{rank}</div>
    <div style={{width:'100%', height, background:SURFACE, border:`3px solid ${color}`, boxShadow:`0 0 16px ${color}66, inset 0 0 24px ${color}22`, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', position:'relative', padding:'10px 6px', gap:6}}>
      {['top:6;left:8','top:6;right:8','bottom:6;left:8','bottom:6;right:8'].map((pos,i)=>{ const st={}; pos.split(';').forEach(kv=>{const[k,v]=kv.split(':');st[k]=parseInt(v);}); return <div key={i} style={{position:'absolute', ...st, fontFamily:'"VT323", monospace', fontSize:14, color, opacity:.7}}>★</div>; })}
      <PhotoAvatar p={p} size={avatar} ring={color} glow={crown}/>
      <div style={{fontFamily:'"VT323", monospace', fontSize:crown?24:20, color:'#fff', lineHeight:1, marginTop:2}}>{p.rating}</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:12, color:'#fff', opacity:.55, letterSpacing:1}}>W{p.w}%</div>
    </div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.7)', letterSpacing:2, marginTop:2}}>{p.name.toUpperCase()}</div>
  </div>
);
const Leaderboard = () => (
  <div style={{padding:'18px 28px 12px', borderBottom:`1px dashed ${MAGENTA}66`}}>
    <div style={{display:'flex', alignItems:'center', justifyContent:'center', gap:14, marginBottom:6}}>
      <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:MAGENTA}}>━━━━</div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:CYAN, letterSpacing:1.5}}>★ HIGH SCORES ★</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:MAGENTA}}>━━━━</div>
    </div>
    <div style={{display:'grid', gridTemplateColumns:'1fr 1.05fr 1fr', gap:10, alignItems:'flex-end', marginTop:10}}>
      <PodiumBlock p={TOP[1]} rank="2ND" color={SILVER} height={150} avatar={54}/>
      <PodiumBlock p={TOP[0]} rank="1ST" color={YELLOW} height={200} crown avatar={72}/>
      <PodiumBlock p={TOP[2]} rank="3RD" color={BRONZE} height={130} avatar={50}/>
    </div>
    <div style={{textAlign:'center', fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.55)', marginTop:10, letterSpacing:2}}>▼ FULL RANKING ▼</div>
  </div>
);
const X01Block = () => (
  <div style={{padding:'18px 28px 0'}}>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, marginBottom:14, letterSpacing:1}}>► PLAYER 1 SELECT</div>
    <div style={{display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:10}}>
      {X01.map((r,i)=>{ const hero=i===1, c=hero?YELLOW:PHOSPHOR; return (
        <div key={r.n} style={{padding:'18px 10px', background:SURFACE, border:`3px solid ${c}`, boxShadow:`0 0 16px ${c}55, inset 0 0 16px ${c}22`, textAlign:'center'}}>
          <div style={{fontSize:32, marginBottom:6}}>{r.em}</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:28, color:c, letterSpacing:1, textShadow:`0 0 8px ${c}aa`}}>{r.n}</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'#fff', opacity:.7, marginTop:6}}>{r.tag.toUpperCase()}</div>
        </div>
      ); })}
    </div>
  </div>
);
const ModesBlock = () => (
  <div style={{padding:'18px 28px 18px', flex:1}}>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, marginBottom:14, letterSpacing:1}}>► OR PICK A LEVEL</div>
    <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:8}}>
      {MODES.map((m)=>(
        <div key={m.k} style={{padding:'12px 14px', background:SURFACE, border:`2px solid ${PHOSPHOR}`, display:'flex', alignItems:'center', gap:12, boxShadow:`0 0 8px ${PHOSPHOR}33`}}>
          <div style={{fontSize:26}}>{m.em}</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#fff', letterSpacing:1, lineHeight:1.4}}>{m.label.toUpperCase()}</div>
        </div>
      ))}
      <div style={{padding:'12px 14px', border:`2px dashed ${MAGENTA}66`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.5)'}}>?? COMING ??</div>
    </div>
  </div>
);
const HomeShell = () => {
  const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
  return (
    <div style={{width:AW, height:AH, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
      <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}/>
      <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 50%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}/>
      <Header/><Leaderboard/><X01Block/><ModesBlock/><Footer/>
    </div>
  );
};
window.HomeVariantShell = HomeShell;

// Locked home: today's design, avatar = photo-or-silhouette (no initials).
const HomeLocked = () => (
  <DCSection
    id="home-locked"
    title="Hjem — dagens design (låst avatar)"
    subtitle="Beholder dagens hjem i sin helhet — podium, modus-grid, X01-rad, footer, marquee. Eneste endring: avataren bruker spillerens eget foto når det finnes, ellers en nøytral person-silhuett (ingen bokstav-initial). Her: Andreas + Jonas har foto, Mia mangler foto → silhuett-fallback.">
    <DCArtboard id="home-locked-art" label="Hjem · foto-eller-silhuett avatar" width={AW} height={AH}><HomeShell/></DCArtboard>
  </DCSection>
);
window.HomeLocked = HomeLocked;
