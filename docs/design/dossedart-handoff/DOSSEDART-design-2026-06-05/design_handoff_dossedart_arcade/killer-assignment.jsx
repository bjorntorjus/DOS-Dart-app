// DOSSEDART — Killer assignment phase (throw to claim your number)
// Pre-game state when throwToPick is on. Players take turns throwing ONE dart:
// the number hit becomes theirs. Miss (0) / bull (25) / already-taken → throw
// again. When all have a number → play begins. (Random mode skips this.)
// Board = input: available numbers bright, claimed numbers dimmed + locked.
// Active claimer = cyan (same active-colour rule as the cockpits).

const KA_W = 820, KA_H = 1180;

const YELLOW  = '#FFD200';
const MAGENTA = '#FF00AA';
const CYAN    = '#00E5FF';
const GREEN   = '#3DFF8E';
const RED      = '#FF3050';
const ORANGE  = '#FF7A00';
const BG      = '#0a0014';
const PHOSPHOR= '#D9D2C2';

if (typeof document !== 'undefined' && !document.getElementById('ka-kf')) {
  const s = document.createElement('style');
  s.id = 'ka-kf';
  s.textContent = `
    @keyframes kaPulse { 0%,100%{opacity:1} 50%{opacity:.45} }
    @keyframes kaWarn { 0%,100%{box-shadow:0 0 10px ${RED}55; border-color:${RED}} 50%{box-shadow:0 0 22px ${RED}cc; border-color:#ff7088} }
    @media (prefers-reduced-motion: reduce){ .ka-pulse,.ka-warn{animation:none!important} }`;
  document.head.appendChild(s);
}

const SEGMENTS = [20,1,18,4,13,6,10,15,2,17,3,19,7,16,8,11,14,9,12,5];
const TWI = { singles:['#1e0c40','#321760'], ring:['#1fb0c9','#c72e94'] };
const R_BULL=0.12, R_TRI_I=0.47, R_TRI_O=0.58, R_DBL_I=0.82, R_DBL_O=0.95, R_RIM=1.00, R_NUM=0.975, R_DBULL=0.05;
const wedge = (cx,cy,rIn,rOut,a1,a2) => {
  const px=(r,a)=>cx+r*Math.cos(a), py=(r,a)=>cy+r*Math.sin(a);
  const large=(a2-a1)>Math.PI?1:0;
  return [`M ${px(rIn,a1)} ${py(rIn,a1)}`,`L ${px(rOut,a1)} ${py(rOut,a1)}`,`A ${rOut} ${rOut} 0 ${large} 1 ${px(rOut,a2)} ${py(rOut,a2)}`,`L ${px(rIn,a2)} ${py(rIn,a2)}`,`A ${rIn} ${rIn} 0 ${large} 0 ${px(rIn,a1)} ${py(rIn,a1)}`,'Z'].join(' ');
};

const Avatar = ({ size=44, color=PHOSPHOR }) => (
  <div style={{width:size, height:size, borderRadius:'50%', background:'#1a0030', border:`2px solid ${color}`, display:'flex', alignItems:'flex-end', justifyContent:'center', flexShrink:0, overflow:'hidden'}}>
    <svg width={size*0.8} height={size*0.8} viewBox="0 0 24 24" style={{marginBottom:-1}}><circle cx="12" cy="9" r="4.2" fill={color} opacity="0.9"/><path d="M3.5 22c0-5 3.8-8 8.5-8s8.5 3 8.5 8z" fill={color} opacity="0.9"/></svg>
  </div>
);

// board: claimed numbers dimmed + locked, available bright, optional taken-flash
const AssignBoard = ({ size=560, claims, taken }) => {
  const cx=size/2, cy=size/2, R=size*0.47, seg=(2*Math.PI)/20;
  const segAngles = SEGMENTS.map((_,i)=>{ const c=-Math.PI/2+i*seg; return [c-seg/2,c+seg/2]; });
  const isClaimed = (n)=>claims[n]!==undefined;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{display:'block'}}>
      <circle cx={cx} cy={cy} r={R*R_RIM} fill="#000"/>
      {segAngles.map(([a1,a2],i)=><path key={`is${i}`} d={wedge(cx,cy,R_BULL*R,R_TRI_I*R,a1,a2)} fill={TWI.singles[i%2]}/>)}
      {segAngles.map(([a1,a2],i)=><path key={`t${i}`} d={wedge(cx,cy,R_TRI_I*R,R_TRI_O*R,a1,a2)} fill={TWI.ring[i%2]}/>)}
      {segAngles.map(([a1,a2],i)=><path key={`os${i}`} d={wedge(cx,cy,R_TRI_O*R,R_DBL_I*R,a1,a2)} fill={TWI.singles[i%2]}/>)}
      {segAngles.map(([a1,a2],i)=><path key={`d${i}`} d={wedge(cx,cy,R_DBL_I*R,R_DBL_O*R,a1,a2)} fill={TWI.ring[i%2]}/>)}
      {/* claimed segments → dark veil */}
      {SEGMENTS.map((n,i)=> isClaimed(n) && <path key={`cl${n}`} d={wedge(cx,cy,R_BULL*R,R_DBL_O*R,segAngles[i][0],segAngles[i][1])} fill="rgba(8,0,18,0.74)"/>)}
      {/* taken-attempt flash */}
      {taken!==undefined && (()=>{ const i=SEGMENTS.indexOf(taken); return <path className="ka-pulse" d={wedge(cx,cy,R_BULL*R,R_DBL_O*R,segAngles[i][0],segAngles[i][1])} fill={`${RED}33`} stroke={RED} strokeWidth="3" style={{animation:'kaPulse 0.7s ease-in-out infinite'}}/>; })()}
      {segAngles.map(([a1],i)=>{ const x1=cx+Math.cos(a1)*R_BULL*R, y1=cy+Math.sin(a1)*R_BULL*R, x2=cx+Math.cos(a1)*R_DBL_O*R, y2=cy+Math.sin(a1)*R_DBL_O*R; return <line key={`sp${i}`} x1={x1} y1={y1} x2={x2} y2={y2} stroke="rgba(0,0,0,0.6)" strokeWidth="1"/>; })}
      <circle cx={cx} cy={cy} r={(R_DBL_O+(R_RIM-R_DBL_O)/2)*R} fill="none" stroke={BG} strokeWidth={(R_RIM-R_DBL_O)*R}/>
      {/* bull = always unavailable for claiming */}
      <circle cx={cx} cy={cy} r={R_BULL*R} fill="#1a0030" stroke="rgba(255,255,255,0.2)" strokeWidth="2"/>
      <circle cx={cx} cy={cy} r={R_DBULL*R} fill="#1a0030" stroke="rgba(255,255,255,0.2)" strokeWidth="1.5"/>
      {/* lock icon on claimed numbers */}
      {SEGMENTS.map((n,i)=>{ if(!isClaimed(n)) return null; const c=-Math.PI/2+i*seg, x=cx+Math.cos(c)*R_NUM*R, y=cy+Math.sin(c)*R_NUM*R; return (
        <g key={`lk${n}`} transform={`translate(${x-7},${y-16})`}><rect x="2" y="6" width="10" height="7" rx="1" fill="rgba(255,255,255,0.5)"/><path d="M4 6V4.5a3 3 0 0 1 6 0V6" fill="none" stroke="rgba(255,255,255,0.5)" strokeWidth="1.5"/></g>
      ); })}
      {/* numbers */}
      {SEGMENTS.map((n,i)=>{ const c=-Math.PI/2+i*seg, x=cx+Math.cos(c)*R_NUM*R, y=cy+Math.sin(c)*R_NUM*R; const claimed=isClaimed(n), isTaken=n===taken; return <text key={`n${i}`} x={x} y={y+4} fontFamily="'Press Start 2P', monospace" fontSize="11" fill={isTaken?RED:claimed?'rgba(255,255,255,0.4)':'#fff'} textAnchor="middle">{n}</text>; })}
    </svg>
  );
};

// ── chrome ──────────────────────────────────────────────────────
const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
const Frame = ({ children }) => (
  <div style={{width:KA_W, height:KA_H, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
    <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}></div>
    <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
    {children}
  </div>
);
const TopBar = () => (
  <div style={{padding:'14px 22px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:14, position:'relative', zIndex:6}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:2}}>◀ EXIT</div>
    <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:11, color:YELLOW, letterSpacing:2, textShadow:`0 0 6px ${YELLOW}88`}}>KILLER · TILDELING</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>3 LIV</div>
  </div>
);

const ROSTER = [
  { name:'Jonas',   num:20, state:'done' },
  { name:'Andreas', num:7,  state:'done' },
  { name:'Mia',     state:'current' },
  { name:'Sander',  state:'wait' },
];
const CLAIMS = { 20:'Jonas', 7:'Andreas' };

// current claimer prompt (cyan) OR taken-feedback (red)
const Prompt = ({ taken }) => (
  <div className={taken!==undefined?'ka-warn':''} style={{margin:'14px 16px 0', padding:'13px 16px', display:'flex', alignItems:'center', gap:14,
    border:`3px solid ${taken!==undefined?RED:CYAN}`, background:taken!==undefined?`${RED}14`:`${CYAN}12`,
    boxShadow:`0 0 18px ${taken!==undefined?RED:CYAN}44`, animation:taken!==undefined?'kaWarn 0.7s ease-in-out infinite':'none'}}>
    <Avatar size={46} color={taken!==undefined?RED:CYAN}/>
    <div style={{flex:1, minWidth:0}}>
      {taken!==undefined ? (
        <>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:RED, letterSpacing:1, textShadow:`0 0 6px ${RED}aa`}}>{taken} ER TATT</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:17, color:'rgba(255,255,255,0.8)', letterSpacing:1, marginTop:5}}>MIA — kast igjen for å velge et ledig tall</div>
        </>
      ) : (
        <>
          <div style={{display:'flex', alignItems:'center', gap:10}}>
            <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:14, color:CYAN, letterSpacing:1.5, textShadow:`0 0 6px ${CYAN}aa`}}>▶ MIA</span>
            <span style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>SPILLER 3 AV 4</span>
          </div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.8)', letterSpacing:1, marginTop:6}}>KAST for å velge ditt tall</div>
        </>
      )}
    </div>
  </div>
);

const RosterStrip = () => (
  <div style={{display:'flex', gap:10, padding:'0 16px 16px'}}>
    {ROSTER.map(p=>{
      const cur=p.state==='current', done=p.state==='done';
      const col = cur?CYAN:done?PHOSPHOR:'rgba(255,255,255,0.3)';
      return (
        <div key={p.name} className={cur?'ka-pulse':''} style={{flex:1, padding:'11px 8px', textAlign:'center', border:`2px solid ${cur?CYAN:done?`${PHOSPHOR}33`:'rgba(255,255,255,0.12)'}`, background:cur?`${CYAN}12`:'transparent', animation:cur?'kaPulse 1.1s ease-in-out infinite':'none'}}>
          <div style={{display:'flex', justifyContent:'center', marginBottom:7}}><Avatar size={32} color={col}/></div>
          <div style={{fontFamily:'"Inter", system-ui, sans-serif', fontWeight:700, fontSize:13, color:cur?CYAN:done?'#fff':'rgba(255,255,255,0.5)', whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{p.name}</div>
          <div style={{marginTop:6}}>
            {done && <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:18, color:'#fff'}}>{p.num} <span style={{color:GREEN, fontSize:11}}>✓</span></span>}
            {cur && <span style={{fontFamily:'"VT323", monospace', fontSize:15, color:CYAN, letterSpacing:1}}>VELGER…</span>}
            {p.state==='wait' && <span style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.4)', letterSpacing:1}}>VENTER</span>}
          </div>
        </div>
      );
    })}
  </div>
);

const Screen = ({ taken }) => (
  <Frame>
    <TopBar/>
    <Prompt taken={taken}/>
    <div style={{flex:1, position:'relative', display:'flex', alignItems:'center', justifyContent:'center', minHeight:0}}>
      <div style={{position:'absolute', width:540, height:540, borderRadius:'50%', boxShadow:`0 0 70px ${MAGENTA}30`, pointerEvents:'none'}}></div>
      <AssignBoard size={560} claims={CLAIMS} taken={taken}/>
      <div style={{position:'absolute', left:16, bottom:6, fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.45)', letterSpacing:1}}>låst tall = opptatt · bom / bull = kast igjen</div>
    </div>
    <RosterStrip/>
  </Frame>
);

// ── spec ────────────────────────────────────────────────────────
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
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>Implementasjon · Killer-tildeling</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:27, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Killer · velg tall</div>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Når</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Pre-game når <code style={{fontFamily:'"JetBrains Mono",monospace', fontSize:11, background:'#ece7dd', padding:'1px 4px'}}>throwToPick</code> er på (KillerPhase.assignment). Spillere kaster ÉN dart i tur og rekkefølge — tallet de treffer blir deres. Når alle har et tall → KillerPhase.playing. Random-modus hopper over hele dette og auto-tildeler.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Regler → kilde</div>
      <SpecRow zone="Treff ledig tall → ditt" val="assignedNumbers[i] = segment" hex={GREEN}/>
      <SpecRow zone="Tall opptatt → kast igjen" val="assignedNumbers.contains(seg)" hex={RED}/>
      <SpecRow zone="Bom (0) / Bull (25) → kast igjen" val="segment==0 || ==25" hex={ORANGE}/>
      <SpecRow zone="Aktiv kaster" val="assignmentPlayerIndex (cyan)" hex={CYAN}/>
      <SpecRow zone="Låst / opptatt felt" val="dimmet + lås" hex={PHOSPHOR}/>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:8, textTransform:'uppercase', letterSpacing:0.5}}>Bygg + best practice</div>
      {[
        ['1','Brett = input','Gjenbruk X01/Killer-brettet (TWILIGHT). Ledige tall lyse, opptatte dimmet + lås-ikon. Bull/d-bull alltid utilgjengelig (kan ikke eies). Tap = velg.'],
        ['2','Aktiv kaster = cyan','Prompt-band: avatar + «{navn} — KAST for å velge ditt tall» + «spiller n av N». Samme active=cyan-regel som cockpitene.'],
        ['3','Kast-igjen-tilstand','Treff opptatt/bom/bull → rødt band «{tall} ER TATT — kast igjen», feltet blinker rødt. Ingen tur går tapt før et gyldig tall er valgt.'],
        ['4','Roster','Stripe nederst: hver spiller med sitt valgte tall + ✓ (ferdig), VELGER… (aktiv, cyan puls), VENTER (dim). Fulle navn.'],
        ['5','Overgang','Når siste spiller har valgt → fade til Killer-cockpiten (battle board). Undo i denne fasen angrer siste tildeling.'],
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
        <b>Konsistens:</b> samme brett + tokens som Killer-cockpiten. Tildeling = «hvem eier hva»; cockpiten viser så kampen (du cyan, fiender røde). Lås-ikon = opptatt.
      </div>
    </div>
  </div>
);

// ── Canvas ──────────────────────────────────────────────────────
const KillerAssignment = () => (
  <DCSection
    id="killer-assignment"
    title="Killer — tildeling (velg tall)"
    subtitle="Pre-game når throw-to-pick er på: spillere kaster én dart i tur for å eie et tall (1–20). Brett = input — ledige tall lyse, opptatte dimmet + lås. Treff opptatt/bom/bull → kast igjen. Aktiv kaster = cyan, roster nederst. Samme brett som Killer-cockpiten.">
    <DCArtboard id="ka-claim" label="Velger · Mia (spiller 3/4)" width={KA_W} height={KA_H}><Screen/></DCArtboard>
    <DCArtboard id="ka-taken" label="Kast igjen · «20 er tatt»" width={KA_W} height={KA_H}><Screen taken={20}/></DCArtboard>
    <DCArtboard id="ka-spec" label="Implementasjon · spec + regler" width={680} height={1180}><SpecCard/></DCArtboard>
  </DCSection>
);
window.KillerAssignment = KillerAssignment;
