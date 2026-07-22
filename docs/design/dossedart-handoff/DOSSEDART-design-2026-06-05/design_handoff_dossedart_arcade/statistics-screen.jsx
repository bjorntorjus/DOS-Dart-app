// DOSSEDART — Statistics screen (tabbed hub, 4 views)
// Reached from the post-game ▤ STATS entry point and home. A browse hub, not a
// single hero — so this is ONE screen shown across its four tabs:
//   PROFIL     — a player's ELO/rank, win%, rating-history graph, per-mode
//                breakdown, head-to-head  (landing tab)  ← the heart
//   MODUS      — per-mode leaderboard (rank by win%, key counters)
//   HEATMAP    — dartboard throw-heat for a player/mode
//   HISTORIKK  — recent matches (mode · date · winner · your ΔELO)
//
// Data straight from SavedPlayer/ModeStats/GameHistory. Locked: you=cyan,
// gold=1st/leader, full names, same arcade chrome. No emoji (brand).

const ST_W = 820, ST_H = 1180;

const YELLOW  = '#FFD200';
const MAGENTA = '#FF00AA';
const CYAN    = '#00E5FF';
const GREEN   = '#3DFF8E';
const RED      = '#FF3050';
const ORANGE  = '#FF7A00';
const BG      = '#0a0014';
const SURFACE = '#1a0030';
const PHOSPHOR= '#D9D2C2';
const SILVER  = '#c9d2da';
const BRONZE  = '#d08a4a';

// ── Data (Jonas = you) ──────────────────────────────────────────
const ME = {
  name:'Jonas', rank:1, of:4, rating:1287,
  games:142, won:78, winPct:55,
  avg:58.3, best:140,
};
const RATING_HISTORY = [1180,1172,1205,1198,1231,1224,1258,1249,1270,1287];
const MODE_MINI = [
  { key:'x01',     label:'X01',      win:62, best:'140' },
  { key:'cricket', label:'CRICKET',  win:48, best:'41 p' },
  { key:'atc',     label:'CLOCK',    win:55, best:'12 pil' },
  { key:'killer',  label:'KILLER',   win:40, best:'4 kills' },
  { key:'split',   label:'SPLITSCORE',win:50, best:'288' },
  { key:'shanghai',label:'SHANGHAI', win:33, best:'Shanghai!' },
];
const H2H = [
  { name:'Andreas', w:12, l:9 },
  { name:'Mia',     w:18, l:4 },
  { name:'Sander',  w:7,  l:11 },
];
// MODUS tab — X01 leaderboard
const MODE_BOARD = [
  { place:1, name:'Andreas', win:64, avg:57.1, best:140, co:23 },
  { place:2, name:'Jonas',   you:true, win:62, avg:58.3, best:140, co:19 },
  { place:3, name:'Mia',     win:41, avg:41.8, best:121, co:8 },
  { place:4, name:'Sander',  win:38, avg:39.2, best:114, co:6 },
];
// HEATMAP — intensity per segment (0..1), top-heavy on 20/19/T-zones
const HEAT = { 20:1.0, 19:0.66, 18:0.34, 17:0.22, 16:0.18, 5:0.3, 1:0.24, 25:0.5, 3:0.16, 7:0.2 };
// HISTORIKK — recent matches
const HISTORY = [
  { mode:'X01 · 501', date:'I dag · 20:14', winner:'Jonas', place:1, elo:+12.3, you:true },
  { mode:'Cricket',   date:'I dag · 19:38', winner:'Andreas', place:2, elo:-4.1 },
  { mode:'Shanghai',  date:'I går · 21:02', winner:'Jonas', place:1, elo:+9.7, you:true, shanghai:true },
  { mode:'Killer',    date:'I går · 20:20', winner:'Mia', place:3, elo:-7.5 },
  { mode:'Splitscore',date:'2 dgr · 18:45', winner:'Jonas', place:1, elo:+6.2, you:true },
  { mode:'Around the Clock', date:'3 dgr · 19:10', winner:'Sander', place:2, elo:+1.8 },
];

const TABS = [ ['profil','PROFIL'], ['modus','MODUS'], ['heatmap','HEATMAP'], ['historikk','HISTORIKK'] ];

// ── bits ────────────────────────────────────────────────────────
const Avatar = ({ size=48, color=PHOSPHOR }) => (
  <div style={{width:size, height:size, borderRadius:'50%', background:'#1a0030', border:`2px solid ${color}`, display:'flex', alignItems:'flex-end', justifyContent:'center', flexShrink:0, overflow:'hidden', boxShadow:`0 0 12px ${color}44`}}>
    <svg width={size*0.8} height={size*0.8} viewBox="0 0 24 24" style={{marginBottom:-1}}>
      <circle cx="12" cy="9" r="4.4" fill={color} opacity="0.9"/>
      <path d="M3.5 22c0-5 3.8-8 8.5-8s8.5 3 8.5 8z" fill={color} opacity="0.9"/>
    </svg>
  </div>
);
const placeColor = (p) => p===1?YELLOW:p===2?SILVER:p===3?BRONZE:'rgba(217,210,194,0.55)';

// win-rate donut
const WinRing = ({ pct, size=92 }) => {
  const r=size/2-7, c=2*Math.PI*r, cx=size/2;
  const col = pct>=55?GREEN:pct>=45?YELLOW:ORANGE;
  return (
    <div style={{position:'relative', width:size, height:size}}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <circle cx={cx} cy={cx} r={r} fill="none" stroke="rgba(255,255,255,0.1)" strokeWidth="7"/>
        <circle cx={cx} cy={cx} r={r} fill="none" stroke={col} strokeWidth="7" strokeDasharray={`${c*pct/100} ${c}`} strokeLinecap="round" transform={`rotate(-90 ${cx} ${cx})`} style={{filter:`drop-shadow(0 0 4px ${col}aa)`}}/>
      </svg>
      <div style={{position:'absolute', inset:0, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center'}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:18, color:col, textShadow:`0 0 8px ${col}aa`}}>{pct}%</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.5)', letterSpacing:1}}>SEIER</div>
      </div>
    </div>
  );
};

// ELO rating line graph
const RatingGraph = ({ data, w=740, h=150 }) => {
  const min=Math.min(...data), max=Math.max(...data), pad=18;
  const xs=(i)=>pad+i*(w-2*pad)/(data.length-1);
  const ys=(v)=>h-pad-((v-min)/(max-min||1))*(h-2*pad);
  const pts=data.map((v,i)=>`${xs(i)},${ys(v)}`).join(' ');
  const area=`${pad},${h-pad} ${pts} ${xs(data.length-1)},${h-pad}`;
  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{display:'block'}}>
      {[0,0.5,1].map((g,i)=><line key={i} x1={pad} y1={pad+g*(h-2*pad)} x2={w-pad} y2={pad+g*(h-2*pad)} stroke="rgba(255,0,170,0.12)" strokeWidth="1"/>)}
      <polygon points={area} fill={`${CYAN}14`}/>
      <polyline points={pts} fill="none" stroke={CYAN} strokeWidth="2.5" style={{filter:`drop-shadow(0 0 5px ${CYAN}aa)`}}/>
      {data.map((v,i)=><circle key={i} cx={xs(i)} cy={ys(v)} r={i===data.length-1?4.5:2.5} fill={i===data.length-1?YELLOW:CYAN} style={i===data.length-1?{filter:`drop-shadow(0 0 5px ${YELLOW})`}:{}}/>)}
      <text x={pad} y={ys(data[0])-8} fontFamily="'VT323', monospace" fontSize="15" fill="rgba(255,255,255,0.5)">{data[0]}</text>
      <text x={w-pad} y={ys(data[data.length-1])-10} fontFamily="'Press Start 2P', monospace" fontSize="10" fill={YELLOW} textAnchor="end">{data[data.length-1]}</text>
    </svg>
  );
};

const BigStat = ({ label, value, color='#fff' }) => (
  <div style={{flex:1, padding:'12px 10px', border:`1px solid ${MAGENTA}33`, background:'rgba(255,255,255,0.02)', textAlign:'center'}}>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:22, color, textShadow:`0 0 8px ${color}66`, lineHeight:1}}>{value}</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:1.5, marginTop:7}}>{label}</div>
  </div>
);

// ── Shared chrome ───────────────────────────────────────────────
const Frame = ({ children, h=ST_H }) => {
  const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
  return (
    <div style={{width:ST_W, height:h, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
      <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}></div>
      <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
      {children}
    </div>
  );
};
const Header = () => (
  <div style={{padding:'12px 18px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:12, position:'relative', zIndex:6}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:2}}>◀ TILBAKE</div>
    <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:12, color:YELLOW, letterSpacing:2, textShadow:`0 0 6px ${YELLOW}88`}}>STATISTIKK</div>
    <div style={{width:74}}></div>
  </div>
);
const TabBar = ({ active }) => (
  <div style={{display:'flex', background:'#000', borderBottom:`2px solid ${MAGENTA}55`, position:'relative', zIndex:6}}>
    {TABS.map(([k,l])=>{
      const on = k===active;
      return (
        <div key={k} style={{flex:1, padding:'13px 4px', textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:9, letterSpacing:1, color:on?CYAN:'rgba(255,255,255,0.4)', borderBottom:on?`3px solid ${CYAN}`:'3px solid transparent', background:on?`${CYAN}12`:'transparent', textShadow:on?`0 0 6px ${CYAN}aa`:'none'}}>{l}</div>
      );
    })}
  </div>
);
// player selector chips (profile/heatmap)
const PlayerChips = ({ sel='Jonas' }) => (
  <div style={{display:'flex', gap:8, padding:'12px 16px 0', flexWrap:'wrap'}}>
    {['Jonas','Andreas','Mia','Sander'].map(n=>{
      const on=n===sel;
      return <div key={n} style={{display:'flex', alignItems:'center', gap:7, padding:'6px 11px 6px 7px', border:`2px solid ${on?CYAN:`${PHOSPHOR}33`}`, background:on?`${CYAN}14`:'transparent'}}>
        <Avatar size={22} color={on?CYAN:PHOSPHOR}/>
        <span style={{fontFamily:'"Inter", system-ui, sans-serif', fontWeight:700, fontSize:13, color:on?CYAN:PHOSPHOR}}>{n}{on?' ·DEG':''}</span>
      </div>;
    })}
  </div>
);

// ════════════════════════════════════════════════════════════════
// PROFIL (player main page)
// ════════════════════════════════════════════════════════════════
const rarityCol = (r) => r<=10?YELLOW : r<=30?CYAN : 'rgba(217,210,194,0.6)';
const tierC = (t) => t==='gold'?YELLOW : t==='silver'?'#c9d2da' : '#d08a4a';
const ACH_PROF = [
  { icon:'bolt',   name:'180!',           desc:'Score maks 180 i X01',           tier:'gold',   rarity:18, date:'14. mai' },
  { icon:'star',   name:'SHANGHAI!',      desc:'Vinn en kamp med direkte Shanghai (S+D+T)', tier:'gold', rarity:6, date:'9. mai' },
  { icon:'flame',  name:'COMEBACK',       desc:'Vinn Splitscore etter å ha blitt halvert', tier:'silver', rarity:22, date:'6. mai' },
  { icon:'target', name:'CHECKOUT-KONGE', desc:'Fullfør 10 checkouts totalt i X01', tier:'bronze', rarity:31, prog:[7,10] },
];
const ProfIcon = ({ name, color, size=26 }) => {
  const p={width:size,height:size,viewBox:'0 0 24 24',fill:'none',stroke:color,strokeWidth:2,strokeLinejoin:'round',strokeLinecap:'round'};
  switch(name){
    case 'bolt':   return <svg {...p}><polygon points="13,2 4,14 11,14 10,22 20,9 13,9" fill={color} stroke="none"/></svg>;
    case 'star':   return <svg {...p}><polygon points="12,2 15,9 22,9.5 16.5,14 18.5,21 12,17 5.5,21 7.5,14 2,9.5 9,9" fill={color} stroke="none"/></svg>;
    case 'flame':  return <svg {...p}><path d="M12 2c1 4 5 5 5 10a5 5 0 0 1-10 0c0-2 1-3 2-4 .5 2 2 2 2 2 0-3-1-5 1-8z" fill={color} fillOpacity="0.3"/></svg>;
    case 'target': return <svg {...p}><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4.5"/><circle cx="12" cy="12" r="1.4" fill={color} stroke="none"/></svg>;
    default: return <svg {...p}><circle cx="12" cy="12" r="9"/></svg>;
  }
};
const ProfBadge = ({ icon, tier, locked, size=58 }) => {
  const c = locked?'rgba(217,210,194,0.3)':tierC(tier);
  return (
    <div style={{position:'relative', width:size, height:size, flexShrink:0}}>
      <svg width={size} height={size} viewBox="0 0 100 100" style={{filter:locked?'none':`drop-shadow(0 0 6px ${c}88)`}}>
        <polygon points="50,5 91,28 91,72 50,95 9,72 9,28" fill={`${c}1f`} stroke={c} strokeWidth="5"/>
      </svg>
      <div style={{position:'absolute', inset:0, display:'flex', alignItems:'center', justifyContent:'center'}}><ProfIcon name={icon} color={c} size={size*0.42}/></div>
    </div>
  );
};
const ProfAchCard = ({ a }) => {
  const locked = !!a.prog;
  const c = locked?'rgba(217,210,194,0.3)':tierC(a.tier);
  return (
    <div style={{display:'flex', gap:13, padding:'12px 13px', border:`2px solid ${locked?`${MAGENTA}30`:`${c}66`}`, background:locked?'rgba(255,255,255,0.015)':`${c}0c`, alignItems:'center'}}>
      <ProfBadge icon={a.icon} tier={a.tier} locked={locked}/>
      <div style={{flex:1, minWidth:0}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:locked?'rgba(255,255,255,0.7)':'#fff', letterSpacing:.5}}>{a.name}</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.6)', letterSpacing:.5, marginTop:5, lineHeight:1.3}}>{a.desc}</div>
        <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', gap:8, marginTop:7}}>
          <span style={{fontFamily:'"VT323", monospace', fontSize:13, color:locked?'rgba(255,255,255,0.4)':GREEN, letterSpacing:1}}>{a.prog?`${a.prog[0]} / ${a.prog[1]}`:`✓ LÅST OPP · ${a.date}`}</span>
          <span style={{fontFamily:'"VT323", monospace', fontSize:14, color:rarityCol(a.rarity), letterSpacing:1, textShadow:`0 0 6px ${rarityCol(a.rarity)}55`}}>{a.rarity}% har denne</span>
        </div>
      </div>
    </div>
  );
};
const ProfileView = () => (
  <div style={{flex:1, display:'flex', flexDirection:'column', minHeight:0, overflow:'hidden'}}>
    <PlayerChips sel="Jonas"/>
    <div style={{padding:'14px 16px 0', display:'flex', alignItems:'center', gap:16}}>
      <Avatar size={72} color={CYAN}/>
      <div style={{flex:1, minWidth:0}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:20, color:'#fff', letterSpacing:1}}>{ME.name.toUpperCase()}</div>
        <div style={{display:'flex', alignItems:'center', gap:10, marginTop:8}}>
          <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:YELLOW, textShadow:`0 0 6px ${YELLOW}88`}}>#{ME.rank}</span>
          <span style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.5)', letterSpacing:1}}>av {ME.of} · </span>
          <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:14, color:CYAN, textShadow:`0 0 6px ${CYAN}88`}}>{ME.rating}</span>
          <span style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.5)', letterSpacing:1}}>ELO</span>
        </div>
      </div>
      <WinRing pct={ME.winPct}/>
    </div>
    <div style={{display:'flex', gap:10, padding:'14px 16px 0'}}>
      <BigStat label="KAMPER" value={ME.games}/>
      <BigStat label="SEIRE" value={ME.won} color={GREEN}/>
      <BigStat label="TAP" value={ME.games - ME.won} color={RED}/>
      <BigStat label="SNITT" value={ME.avg} color={CYAN}/>
    </div>
    <div style={{padding:'16px 16px 0'}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.5)', letterSpacing:2, marginBottom:8}}>RATING-HISTORIKK · ELO</div>
      <div style={{border:`1px solid ${MAGENTA}33`, padding:'4px 0'}}><RatingGraph data={RATING_HISTORY}/></div>
    </div>
    {/* PER MODUS sammendrag — detaljer i MODUS-fanen */}
    <div style={{padding:'16px 16px 0'}}>
      <div style={{display:'flex', alignItems:'center', gap:10, marginBottom:8}}>
        <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>PER MODUS · SEIER%</span>
        <div style={{flex:1}}></div>
        <span style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.4)', letterSpacing:1}}>detaljer i MODUS-fanen ›</span>
      </div>
      <div style={{display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:8}}>
        {MODE_MINI.map(m=>{ const col=m.win>=55?GREEN:m.win>=45?YELLOW:ORANGE; return (
          <div key={m.key} style={{border:`1px solid ${MAGENTA}33`, padding:'9px 8px', background:'rgba(255,255,255,0.02)'}}>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:8, color:PHOSPHOR, letterSpacing:.5, whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{m.label}</div>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:17, color:col, marginTop:6, textShadow:`0 0 6px ${col}66`}}>{m.win}%</div>
            <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.45)', letterSpacing:1, marginTop:3}}>{m.best}</div>
          </div>
        ); })}
      </div>
    </div>
    {/* PRESTASJONER — lenger nede, større, med forklaring på hvorfor */}
    <div style={{padding:'20px 16px 0'}}>
      <div style={{display:'flex', alignItems:'center', gap:10, marginBottom:11}}>
        <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:MAGENTA, letterSpacing:2, textShadow:`0 0 6px ${MAGENTA}66`}}>PRESTASJONER</span>
        <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:YELLOW, textShadow:`0 0 6px ${YELLOW}88`}}>12 / 30</span>
        <div style={{flex:1}}></div>
        <span style={{fontFamily:'"VT323", monospace', fontSize:15, color:CYAN, letterSpacing:1}}>SE ALLE ›</span>
      </div>
      <div style={{display:'flex', flexDirection:'column', gap:9}}>
        {ACH_PROF.map(a => <ProfAchCard key={a.name} a={a}/>)}
      </div>
    </div>
    <div style={{height:20}}></div>
  </div>
);

// ════════════════════════════════════════════════════════════════
// MODUS — per-mode leaderboard (X01 selected)
// ════════════════════════════════════════════════════════════════
const ModeView = () => (
  <div style={{flex:1, display:'flex', flexDirection:'column', minHeight:0}}>
    <div style={{display:'flex', gap:8, padding:'14px 16px 0', flexWrap:'wrap'}}>
      {['X01','CRICKET','CLOCK','KILLER','SPLITSCORE','SHANGHAI'].map((m,i)=>{
        const on=i===0;
        return <div key={m} style={{padding:'7px 12px', border:`2px solid ${on?YELLOW:`${PHOSPHOR}33`}`, background:on?`${YELLOW}12`:'transparent', fontFamily:'"Press Start 2P", monospace', fontSize:9, letterSpacing:1, color:on?YELLOW:'rgba(255,255,255,0.5)'}}>{m}</div>;
      })}
    </div>
    <div style={{padding:'16px 16px 0'}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.5)', letterSpacing:2, marginBottom:10}}>X01 · LEDERTAVLE · SORTERT PÅ SEIER%</div>
      <div style={{display:'grid', gridTemplateColumns:'44px 1fr 70px 70px 64px 56px', gap:8, padding:'0 12px 8px', borderBottom:`2px solid ${MAGENTA}55`, fontFamily:'"Press Start 2P", monospace', fontSize:8, color:'rgba(255,255,255,0.5)', letterSpacing:.5}}>
        <div>#</div><div>SPILLER</div><div style={{textAlign:'right'}}>SEIER</div><div style={{textAlign:'right'}}>SNITT</div><div style={{textAlign:'right'}}>BEST</div><div style={{textAlign:'right'}}>CO</div>
      </div>
      {MODE_BOARD.map(r=>{
        const c=placeColor(r.place);
        return <div key={r.name} style={{display:'grid', gridTemplateColumns:'44px 1fr 70px 70px 64px 56px', gap:8, alignItems:'center', padding:'14px 12px', borderBottom:`1px solid ${MAGENTA}22`, background:r.place===1?`${YELLOW}0e`:r.you?`${CYAN}0c`:'transparent'}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:15, color:c, textShadow:`0 0 6px ${c}66`}}>{r.place}</div>
          <div style={{display:'flex', alignItems:'center', gap:9, minWidth:0}}>
            <Avatar size={30} color={r.you?CYAN:c}/>
            <span style={{fontFamily:'"Inter", system-ui, sans-serif', fontWeight:700, fontSize:14, color:r.you?CYAN:'#fff', whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{r.name}{r.you?' ·DEG':''}</span>
          </div>
          <div style={{textAlign:'right', fontFamily:'"Press Start 2P", monospace', fontSize:13, color:r.win>=50?GREEN:ORANGE}}>{r.win}%</div>
          <div style={{textAlign:'right', fontFamily:'"Press Start 2P", monospace', fontSize:13, color:'#fff'}}>{r.avg}</div>
          <div style={{textAlign:'right', fontFamily:'"Press Start 2P", monospace', fontSize:13, color:'rgba(255,255,255,0.8)'}}>{r.best}</div>
          <div style={{textAlign:'right', fontFamily:'"Press Start 2P", monospace', fontSize:13, color:'rgba(255,255,255,0.8)'}}>{r.co}</div>
        </div>;
      })}
      <div style={{marginTop:14, fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.45)', letterSpacing:1}}>CO = checkouts · snitt = 3-pilers snitt · best = beste 3-piler</div>
    </div>
  </div>
);

// ════════════════════════════════════════════════════════════════
// HEATMAP — dartboard throw heat
// ════════════════════════════════════════════════════════════════
const SEGMENTS = [20,1,18,4,13,6,10,15,2,17,3,19,7,16,8,11,14,9,12,5];
const HeatBoard = ({ size=440 }) => {
  const cx=size/2, cy=size/2, R=size*0.47, seg=(2*Math.PI)/20;
  const segAngles = SEGMENTS.map((_,i)=>{ const c=-Math.PI/2+i*seg; return c; });
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{display:'block'}}>
      <defs>
        <radialGradient id="heatg">
          <stop offset="0%" stopColor={YELLOW} stopOpacity="0.95"/>
          <stop offset="45%" stopColor={ORANGE} stopOpacity="0.6"/>
          <stop offset="100%" stopColor={RED} stopOpacity="0"/>
        </radialGradient>
      </defs>
      <circle cx={cx} cy={cy} r={R} fill="#120826" stroke={`${MAGENTA}44`} strokeWidth="2"/>
      {/* faint segment spokes + ring */}
      {SEGMENTS.map((n,i)=>{ const a=-Math.PI/2+(i-0.5)*seg; const x=cx+Math.cos(a)*R, y=cy+Math.sin(a)*R; return <line key={i} x1={cx} y1={cy} x2={x} y2={y} stroke="rgba(255,255,255,0.06)" strokeWidth="1"/>; })}
      <circle cx={cx} cy={cy} r={R*0.62} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="1"/>
      <circle cx={cx} cy={cy} r={R*0.12} fill="none" stroke="rgba(255,255,255,0.1)" strokeWidth="1"/>
      {/* heat blobs */}
      {Object.entries(HEAT).map(([n,inten])=>{
        const num=+n;
        if(num===25){ const rad=R*0.34*inten+18; return <circle key={n} cx={cx} cy={cy} r={rad} fill="url(#heatg)"/>; }
        const i=SEGMENTS.indexOf(num); const a=segAngles[i]; const rr=R*0.72;
        const x=cx+Math.cos(a)*rr, y=cy+Math.sin(a)*rr; const rad=R*0.3*inten+12;
        return <circle key={n} cx={x} cy={y} r={rad} fill="url(#heatg)"/>;
      })}
      {/* numbers */}
      {SEGMENTS.map((n,i)=>{ const a=-Math.PI/2+i*seg, x=cx+Math.cos(a)*R*0.92, y=cy+Math.sin(a)*R*0.92; return <text key={i} x={x} y={y+4} fontFamily="'Press Start 2P', monospace" fontSize="10" fill="rgba(255,255,255,0.85)" textAnchor="middle">{n}</text>; })}
    </svg>
  );
};
const HeatmapView = () => (
  <div style={{flex:1, display:'flex', flexDirection:'column', minHeight:0}}>
    <PlayerChips sel="Jonas"/>
    <div style={{display:'flex', gap:8, padding:'12px 16px 0'}}>
      {['X01','CRICKET','ALLE'].map((m,i)=>{ const on=i===0; return <div key={m} style={{padding:'6px 12px', border:`2px solid ${on?YELLOW:`${PHOSPHOR}33`}`, background:on?`${YELLOW}12`:'transparent', fontFamily:'"Press Start 2P", monospace', fontSize:9, color:on?YELLOW:'rgba(255,255,255,0.5)', letterSpacing:1}}>{m}</div>; })}
    </div>
    <div style={{flex:1, display:'flex', alignItems:'center', justifyContent:'center', minHeight:0, position:'relative'}}>
      <div style={{position:'absolute', width:430, height:430, borderRadius:'50%', boxShadow:`0 0 70px ${ORANGE}22`, pointerEvents:'none'}}></div>
      <HeatBoard size={460}/>
    </div>
    <div style={{padding:'0 16px 18px', display:'flex', gap:10}}>
      <BigStat label="MEST TRUFFET" value="20" color={YELLOW}/>
      <BigStat label="TRIPLE-RATE" value="11%" color={CYAN}/>
      <BigStat label="BOM-RATE" value="14%" color={ORANGE}/>
      <BigStat label="PILER LOGGET" value="3.4k"/>
    </div>
  </div>
);

// ════════════════════════════════════════════════════════════════
// HISTORIKK — recent matches
// ════════════════════════════════════════════════════════════════
const HistoryView = () => (
  <div style={{flex:1, display:'flex', flexDirection:'column', minHeight:0, overflow:'hidden'}}>
    <div style={{padding:'16px 16px 8px', fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>SISTE KAMPER</div>
    <div style={{flex:1, padding:'0 16px', display:'flex', flexDirection:'column', gap:9, minHeight:0, overflow:'hidden'}}>
      {HISTORY.map((h,i)=>{
        const up=h.elo>0, eloCol=up?GREEN:RED;
        return (
          <div key={i} style={{display:'flex', alignItems:'center', gap:13, padding:'13px 14px', border:`2px solid ${h.you?`${CYAN}44`:`${MAGENTA}30`}`, background:h.you?`${CYAN}0a`:'rgba(255,255,255,0.02)'}}>
            <div style={{width:54, textAlign:'center'}}>
              <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:placeColor(h.place), textShadow:`0 0 5px ${placeColor(h.place)}66`}}>#{h.place}</div>
            </div>
            <div style={{flex:1, minWidth:0}}>
              <div style={{display:'flex', alignItems:'center', gap:8}}>
                <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:YELLOW, letterSpacing:.5}}>{h.mode}</span>
                {h.shanghai && <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:8, color:BG, background:YELLOW, padding:'2px 5px', letterSpacing:1}}>SHANGHAI!</span>}
              </div>
              <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.5)', letterSpacing:1, marginTop:4}}>{h.date} · vinner <b style={{color:'#fff'}}>{h.winner}</b></div>
            </div>
            <div style={{textAlign:'right'}}>
              <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:eloCol, textShadow:`0 0 5px ${eloCol}66`}}>{up?'▲':'▼'} {up?'+':''}{h.elo.toFixed(1)}</div>
              <div style={{fontFamily:'"VT323", monospace', fontSize:12, color:'rgba(255,255,255,0.4)', letterSpacing:1}}>ELO</div>
            </div>
          </div>
        );
      })}
    </div>
    <div style={{height:14}}></div>
  </div>
);

// ── Screen (one hub, tab-driven) ────────────────────────────────
const StatScreen = ({ tab, h }) => (
  <Frame h={h}>
    <Header/>
    <TabBar active={tab}/>
    {tab==='profil' && <ProfileView/>}
    {tab==='modus' && <ModeView/>}
    {tab==='heatmap' && <HeatmapView/>}
    {tab==='historikk' && <HistoryView/>}
  </Frame>
);

// ── Implementation spec ─────────────────────────────────────────
const SpecRow = ({ zone, val, hex }) => (
  <div style={{display:'flex', alignItems:'center', gap:10, padding:'7px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
    <div style={{width:14, height:14, background:hex, border:'1px solid rgba(0,0,0,0.25)', flexShrink:0}}></div>
    <div style={{flex:1, fontFamily:'"Inter", system-ui, sans-serif', fontSize:13, fontWeight:600, color:'#2a251f'}}>{zone}</div>
    <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:12, color:'#5a544a'}}>{val}</div>
  </div>
);
const SpecCard = () => (
  <div style={{boxSizing:'border-box', width:680, height:1180, background:'#fffdf6', border:'1.5px solid rgba(0,0,0,0.14)', padding:'30px 34px', fontFamily:'"Inter", system-ui, sans-serif', display:'flex', flexDirection:'column', gap:14, overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>Implementasjon · statistikk-hub</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:27, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Statistikk · 4 faner</div>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Struktur</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Én hub med arcade-faner. <b style={{color:'#2a251f'}}>PROFIL</b> er landings-fanen (mest verdi): ELO + rangering, seier-ring, rating-graf, per-modus, head-to-head. <b style={{color:'#2a251f'}}>MODUS</b> = ledertavle per spillmodus. <b style={{color:'#2a251f'}}>HEATMAP</b> = pil-tetthet på brettet. <b style={{color:'#2a251f'}}>HISTORIKK</b> = siste kamper. Data rett fra SavedPlayer / ModeStats / GameHistory.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Datakilder</div>
      <SpecRow zone="Rating + graf" val="rating · ratingHistory[]" hex={CYAN}/>
      <SpecRow zone="Seier% / kamper" val="gamesWon / gamesPlayed" hex={GREEN}/>
      <SpecRow zone="Snitt / beste runde" val="averageTurnScore · highestTurnScore" hex={YELLOW}/>
      <SpecRow zone="Per modus" val="modeStats[mode] (played/won/counters)" hex={MAGENTA}/>
      <SpecRow zone="Head-to-head" val="headToHead{oppId:{W,L,D}}" hex={PHOSPHOR}/>
      <SpecRow zone="Historikk" val="GameHistoryEntry (mode·date·placement·ΔELO)" hex={ORANGE}/>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Heatmap</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Akkumuler treff per segment (eksisterende <code style={{fontFamily:'"JetBrains Mono",monospace', fontSize:11, background:'#ece7dd', padding:'1px 4px'}}>heatmap_board.dart</code>) → radial gult→oransje→rød glød per tall, intensitet = relativ frekvens. Filtrer på spiller + modus.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:8, textTransform:'uppercase', letterSpacing:0.5}}>Bygg + best practice</div>
      {[
        ['1','Arcade-hub','Erstatt classic TabBar/DataTable med DOSSEDART-chrome: header, arcade-fane-strip, kort/lister. Behold de 4 fanene; legg til Shanghai i MODUS (manglet i classic).'],
        ['2','Profil = hjertet','ELO stort + rangering, seier-ring (donut), rating-graf (CustomPaint → samme data), per-modus rutenett, head-to-head. Spiller-velger som chips øverst.'],
        ['3','Tomtilstander','Ingen lagrede spillere / ingen kamper i en modus → vennlig tom-tilstand (som i dag), ikke blank skjerm.'],
        ['4','Fulle navn + deg=cyan','Aldri forkortelser. Innlogget/valgt spiller markeres cyan. Gull/sølv/bronse på ledertavle-plassering.'],
        ['5','Entry-points','Nås fra post-game ▤ STATS og hjem. ◀ TILBAKE returnerer. Innstillinger er en egen skjerm (kommer).'],
      ].map(([n,t,b])=>(
        <div key={n} style={{display:'flex', gap:11, padding:'8px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
          <div style={{flexShrink:0, width:22, height:22, borderRadius:'50%', background:'#2a8a52', color:'#fff', display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"JetBrains Mono", monospace', fontSize:12, fontWeight:700}}>{n}</div>
          <div style={{flex:1}}>
            <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:700, color:'#2a251f', marginBottom:2}}>{t}</div>
            <div style={{fontFamily:'"Inter", sans-serif', fontSize:12, lineHeight:1.5, color:'#5a544a'}}>{b}</div>
          </div>
        </div>
      ))}
    </div>
    <div style={{marginTop:'auto', padding:'12px 14px', background:'#dcefe1', border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, lineHeight:1.55, color:'#2a4a36'}}>
        <b>Konsistens:</b> samme chrome + farge-prinsipp som cockpit-ene og post-game. Cyan=deg, gull=topp, grønn/rød=ELO opp/ned. Heatmap gjenbruker brett-geometrien.
      </div>
    </div>
  </div>
);

// ── Canvas ──────────────────────────────────────────────────────
const StatisticsScreen = () => (
  <DCSection
    id="statistics"
    title="Statistikk — hub (4 faner)"
    subtitle="Nås fra post-game ▤ STATS + hjem. Én hub vist på tvers av sine fire faner: PROFIL (landing — ELO, seier-ring, rating-graf, per-modus, head-to-head), MODUS (ledertavle per modus), HEATMAP (pil-tetthet på brettet), HISTORIKK (siste kamper). Data fra SavedPlayer/ModeStats/GameHistory. Samme arcade-chrome som cockpit-ene.">
    <DCArtboard id="st-profil" label="Fane · PROFIL (hovedside)" width={ST_W} height={1560}><StatScreen tab="profil" h={1560}/></DCArtboard>
    <DCArtboard id="st-modus" label="Fane · MODUS (ledertavle)" width={ST_W} height={ST_H}><StatScreen tab="modus"/></DCArtboard>
    <DCArtboard id="st-heatmap" label="Fane · HEATMAP" width={ST_W} height={ST_H}><StatScreen tab="heatmap"/></DCArtboard>
    <DCArtboard id="st-historikk" label="Fane · HISTORIKK" width={ST_W} height={ST_H}><StatScreen tab="historikk"/></DCArtboard>
    <DCArtboard id="st-spec" label="Implementasjon · spec + datakilder" width={680} height={1180}><SpecCard/></DCArtboard>
  </DCSection>
);
window.StatisticsScreen = StatisticsScreen;
