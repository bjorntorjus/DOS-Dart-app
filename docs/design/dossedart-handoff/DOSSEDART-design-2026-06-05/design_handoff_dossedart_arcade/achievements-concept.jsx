// DOSSEDART — Achievements (CONCEPT · for discussion)
// New feature (no code yet). Grounded in stats the app already tracks
// (ModeStats counters · SavedPlayer fields) so every badge is real & earnable.
// Three pieces:
//   OVERVIEW  — gallery of badges (unlocked / locked / tiered progress)
//   PROFILE   — a PRESTASJONER strip on the statistics PROFIL tab
//   UNLOCK    — popup when one fires (centered takeover-lite + slide-in toast)
// + a concept card with the proposal + open questions.

const AC_W = 820, AC_H = 1180;

const YELLOW  = '#FFD200';
const MAGENTA = '#FF00AA';
const CYAN    = '#00E5FF';
const GREEN   = '#3DFF8E';
const RED      = '#FF3050';
const ORANGE  = '#FF7A00';
const BG      = '#0a0014';
const SURFACE = '#160a2b';
const PHOSPHOR= '#D9D2C2';
const BRONZE  = '#d08a4a';
const SILVER  = '#c9d2da';
const GOLD    = YELLOW;
const LOCK    = 'rgba(217,210,194,0.30)';
const tierColor = (t) => t==='gold'?GOLD:t==='silver'?SILVER:t==='bronze'?BRONZE:LOCK;
const rarityCol = (r) => r<=10 ? GOLD : r<=30 ? CYAN : 'rgba(217,210,194,0.6)';

if (typeof document !== 'undefined' && !document.getElementById('ac-kf')) {
  const s = document.createElement('style');
  s.id = 'ac-kf';
  s.textContent = `
    @keyframes acPop { 0%{transform:scale(.5) rotate(-12deg); opacity:0} 60%{transform:scale(1.12) rotate(3deg); opacity:1} 100%{transform:scale(1) rotate(0)} }
    @keyframes acGlow { 0%,100%{filter:drop-shadow(0 0 8px currentColor)} 50%{filter:drop-shadow(0 0 18px currentColor)} }
    @keyframes acStar { 0%,100%{opacity:.4; transform:translateY(0)} 50%{opacity:1; transform:translateY(-4px)} }
    @keyframes acSlide { 0%{transform:translateY(-120%); opacity:0} 15%,85%{transform:translateY(0); opacity:1} 100%{transform:translateY(-120%); opacity:0} }
    @media (prefers-reduced-motion: reduce){ .ac-pop,.ac-glow,.ac-star,.ac-slide{animation:none!important} }`;
  document.head.appendChild(s);
}

// ── icons (simple arcade glyphs) ────────────────────────────────
const Icon = ({ name, color, size=30 }) => {
  const p = { width:size, height:size, viewBox:'0 0 24 24', fill:'none', stroke:color, strokeWidth:2, strokeLinejoin:'round', strokeLinecap:'round' };
  switch(name){
    case 'bolt': return <svg {...p}><polygon points="13,2 4,14 11,14 10,22 20,9 13,9" fill={color} stroke="none"/></svg>;
    case 'star': return <svg {...p}><polygon points="12,2 15,9 22,9.5 16.5,14 18.5,21 12,17 5.5,21 7.5,14 2,9.5 9,9" fill={color} stroke="none"/></svg>;
    case 'target': return <svg {...p}><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.6" fill={color} stroke="none"/></svg>;
    case 'bull': return <svg {...p}><circle cx="12" cy="12" r="9" stroke={color}/><circle cx="12" cy="12" r="5" fill={color} fillOpacity="0.25"/><circle cx="12" cy="12" r="2.4" fill={color} stroke="none"/></svg>;
    case 'skull': return <svg {...p}><path d="M5 11a7 7 0 0 1 14 0v3l-1.5 1.5V19h-11v-3.5L5 14z" fill={color} fillOpacity="0.2"/><circle cx="9" cy="11" r="1.6" fill={color} stroke="none"/><circle cx="15" cy="11" r="1.6" fill={color} stroke="none"/></svg>;
    case 'shield': return <svg {...p}><path d="M12 2l8 3v6c0 5-3.4 8.7-8 11-4.6-2.3-8-6-8-11V5z" fill={color} fillOpacity="0.18"/></svg>;
    case 'flame': return <svg {...p}><path d="M12 2c1 4 5 5 5 10a5 5 0 0 1-10 0c0-2 1-3 2-4 .5 2 2 2 2 2 0-3-1-5 1-8z" fill={color} fillOpacity="0.25"/></svg>;
    case 'crown': return <svg {...p}><path d="M3 18 L5 7 L9 13 L12 4 L15 13 L19 7 L21 18 Z" fill={color} fillOpacity="0.3"/><rect x="3" y="18" width="18" height="2.5" fill={color} stroke="none"/></svg>;
    default: return <svg {...p}><circle cx="12" cy="12" r="9"/></svg>;
  }
};

// hexagon medal badge
const Badge = ({ icon, tier, locked, size=72 }) => {
  const col = locked?LOCK:tierColor(tier);
  const hex = "50,4 92,27 92,73 50,96 8,73 8,27";
  return (
    <div style={{position:'relative', width:size, height:size, flexShrink:0, color:col}}>
      <svg width={size} height={size} viewBox="0 0 100 100" style={{display:'block', filter:locked?'none':`drop-shadow(0 0 8px ${col}88)`}}>
        <polygon points={hex} fill={`${col}1f`} stroke={col} strokeWidth="4"/>
        <polygon points="50,12 84,31 84,69 50,88 16,69 16,31" fill="none" stroke={col} strokeWidth="1" opacity="0.5"/>
      </svg>
      <div style={{position:'absolute', inset:0, display:'flex', alignItems:'center', justifyContent:'center'}}>
        <Icon name={icon} color={col} size={size*0.42}/>
      </div>
      {locked && <div style={{position:'absolute', right:-2, bottom:-2, width:size*0.36, height:size*0.36, borderRadius:'50%', background:BG, border:`2px solid ${LOCK}`, display:'flex', alignItems:'center', justifyContent:'center'}}>
        <svg width={size*0.2} height={size*0.2} viewBox="0 0 24 24"><rect x="4" y="11" width="16" height="10" rx="1.5" fill={LOCK}/><path d="M8 11V8a4 4 0 0 1 8 0v3" fill="none" stroke={LOCK} strokeWidth="2.5"/></svg>
      </div>}
    </div>
  );
};

const ACH = [
  { icon:'bolt',   name:'180!',           desc:'Score maks 180 i X01',           tier:'gold',   rarity:18, state:'unlocked', date:'14. mai' },
  { icon:'bull',   name:'BULLSEYE',       desc:'Treff dobbel-bull (50)',          tier:'silver', rarity:64, state:'unlocked', date:'2. mai' },
  { icon:'star',   name:'SHANGHAI!',      desc:'Vinn med direkte Shanghai',       tier:'gold',   rarity:6,  state:'unlocked', date:'9. mai' },
  { icon:'flame',  name:'COMEBACK',       desc:'Vinn Splitscore etter halvering', tier:'silver', rarity:22, state:'unlocked', date:'6. mai' },
  { icon:'target', name:'CHECKOUT-KONGE', desc:'10 checkouts totalt',             tier:'bronze', rarity:31, state:'locked',   prog:[7,10] },
  { icon:'skull',  name:'LEIEMORDER',     desc:'5 kills i én Killer-kamp',        tier:'silver', rarity:12, state:'locked',   prog:[3,5] },
  { icon:'shield', name:'OVERLEVENDE',    desc:'Vinn Killer uten å miste liv',    tier:'gold',   rarity:4,  state:'locked' },
  { icon:'crown',  name:'MESTER',         desc:'Nå 1400 ELO',                     tier:'gold',   rarity:9,  state:'locked',   prog:[1287,1400] },
];

// ── chrome ──────────────────────────────────────────────────────
const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
const Frame = ({ children, h=AC_H }) => (
  <div style={{width:AC_W, height:h, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
    <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}></div>
    <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
    {children}
  </div>
);
const Header = ({ title }) => (
  <div style={{padding:'12px 18px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:12, position:'relative', zIndex:6, flexShrink:0}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:2}}>◀ TILBAKE</div>
    <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:12, color:YELLOW, letterSpacing:2, textShadow:`0 0 6px ${YELLOW}88`}}>{title}</div>
    <div style={{width:74}}></div>
  </div>
);

// ── achievement card ────────────────────────────────────────────
const AchCard = ({ a }) => {
  const locked = a.state==='locked';
  const col = locked?LOCK:tierColor(a.tier);
  return (
    <div style={{display:'flex', gap:13, padding:'13px', border:`2px solid ${locked?`${PHOSPHOR}22`:`${col}66`}`, background:locked?'rgba(255,255,255,0.015)':`${col}0c`, alignItems:'center', opacity:locked?0.82:1}}>
      <Badge icon={a.icon} tier={a.tier} locked={locked} size={66}/>
      <div style={{flex:1, minWidth:0}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:locked?'rgba(255,255,255,0.7)':'#fff', letterSpacing:.5}}>{a.name}</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.55)', letterSpacing:.5, marginTop:6, lineHeight:1.3}}>{a.desc}</div>
        {a.prog && <div style={{height:7, background:'rgba(255,255,255,0.1)', position:'relative', marginTop:9}}>
          <div style={{position:'absolute', inset:0, width:`${Math.round(a.prog[0]/a.prog[1]*100)}%`, background:col, boxShadow:`0 0 6px ${col}aa`}}></div>
        </div>}
        <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', gap:8, marginTop:a.prog?6:7}}>
          <span style={{fontFamily:'"VT323", monospace', fontSize:13, color:locked?'rgba(255,255,255,0.4)':GREEN, letterSpacing:1}}>{a.prog?`${a.prog[0]} / ${a.prog[1]}`:locked?'LÅST':`✓ LÅST OPP · ${a.date}`}</span>
          <span style={{fontFamily:'"VT323", monospace', fontSize:14, color:rarityCol(a.rarity), letterSpacing:1, textShadow:`0 0 6px ${rarityCol(a.rarity)}55`}}>{a.rarity}% har denne</span>
        </div>
      </div>
    </div>
  );
};

// ════════════════════════════════════════════════════════════════
// OVERVIEW
// ════════════════════════════════════════════════════════════════
const Overview = () => (
  <Frame>
    <Header title="STATISTIKK · PRESTASJONER"/>
    {/* player + summary */}
    <div style={{padding:'14px 16px 0', flexShrink:0}}>
      <div style={{display:'flex', alignItems:'center', gap:12, marginBottom:12}}>
        <div style={{width:40, height:40, borderRadius:'50%', background:'#1a0030', border:`2px solid ${CYAN}`}}></div>
        <span style={{fontFamily:'"Inter", system-ui, sans-serif', fontWeight:700, fontSize:16, color:CYAN}}>Jonas ·DEG</span>
        <div style={{flex:1}}></div>
        <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:18, color:YELLOW, textShadow:`0 0 8px ${YELLOW}88`}}>12<span style={{color:'rgba(255,255,255,0.4)', fontSize:13}}> / 30</span></span>
      </div>
      <div style={{height:9, background:'rgba(255,255,255,0.1)', position:'relative'}}>
        <div style={{position:'absolute', inset:0, width:'40%', background:`linear-gradient(90deg, ${BRONZE}, ${YELLOW})`, boxShadow:`0 0 8px ${YELLOW}88`}}></div>
      </div>
      <div style={{display:'flex', gap:8, marginTop:14}}>
        {['ALLE','LÅST OPP','LÅST','X01','KILLER'].map((f,i)=>{ const on=i===0; return <div key={f} style={{padding:'6px 11px', border:`2px solid ${on?CYAN:`${PHOSPHOR}33`}`, background:on?`${CYAN}14`:'transparent', fontFamily:'"Press Start 2P", monospace', fontSize:8, color:on?CYAN:'rgba(255,255,255,0.5)', letterSpacing:1}}>{f}</div>; })}
      </div>
    </div>
    {/* grid */}
    <div style={{flex:1, padding:'16px', display:'grid', gridTemplateColumns:'1fr 1fr', gap:11, minHeight:0, overflow:'hidden', alignContent:'start'}}>
      {ACH.map(a => <AchCard key={a.name} a={a}/>)}
    </div>
    <div style={{position:'absolute', left:0, right:0, bottom:0, height:50, background:`linear-gradient(transparent, ${BG})`, pointerEvents:'none', zIndex:6}}></div>
  </Frame>
);

// ════════════════════════════════════════════════════════════════
// PROFILE INTEGRATION (on the statistics PROFIL tab)
// ════════════════════════════════════════════════════════════════
const ProfileIntegration = () => (
  <Frame>
    <Header title="STATISTIKK · PROFIL"/>
    {/* condensed profile context */}
    <div style={{padding:'16px', display:'flex', alignItems:'center', gap:16, borderBottom:`1px solid ${MAGENTA}22`}}>
      <div style={{width:64, height:64, borderRadius:'50%', background:'#1a0030', border:`3px solid ${CYAN}`}}></div>
      <div style={{flex:1}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:18, color:'#fff'}}>JONAS</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.5)', letterSpacing:1, marginTop:6}}>#1 av 4 · <span style={{color:CYAN}}>1287</span> ELO · 55% seier</div>
      </div>
    </div>
    {/* the NEW achievements section */}
    <div style={{padding:'18px 16px 0'}}>
      <div style={{display:'flex', alignItems:'center', gap:10, marginBottom:14}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:MAGENTA, letterSpacing:2, textShadow:`0 0 6px ${MAGENTA}66`}}>PRESTASJONER</div>
        <div style={{flex:1, height:1, background:`${MAGENTA}33`}}></div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:YELLOW}}>12 / 30</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:CYAN, letterSpacing:1}}>SE ALLE ›</div>
      </div>
      {/* recent / featured medallions */}
      <div style={{display:'flex', gap:14, justifyContent:'space-between'}}>
        {ACH.slice(0,4).map(a=>(
          <div key={a.name} style={{display:'flex', flexDirection:'column', alignItems:'center', gap:8, flex:1}}>
            <Badge icon={a.icon} tier={a.tier} locked={a.state==='locked'} size={72}/>
            <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:a.state==='locked'?'rgba(255,255,255,0.4)':'#fff', letterSpacing:.5, textAlign:'center', lineHeight:1.1}}>{a.name}</div>
          </div>
        ))}
        <div style={{display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:8, flex:1}}>
          <div style={{width:72, height:72, display:'flex', alignItems:'center', justifyContent:'center', border:`2px dashed ${PHOSPHOR}33`}}>
            <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:14, color:'rgba(255,255,255,0.5)'}}>+8</span>
          </div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.4)', letterSpacing:.5}}>flere</div>
        </div>
      </div>
      {/* next up */}
      <div style={{marginTop:22}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.5)', letterSpacing:2, marginBottom:10}}>NÆRMEST Å LÅSE OPP</div>
        <div style={{display:'flex', flexDirection:'column', gap:10}}>
          {ACH.filter(a=>a.prog).map(a=><AchCard key={a.name} a={a}/>)}
        </div>
      </div>
    </div>
    <div style={{position:'absolute', left:0, right:0, bottom:0, height:50, background:`linear-gradient(transparent, ${BG})`, pointerEvents:'none', zIndex:6}}></div>
  </Frame>
);

// ════════════════════════════════════════════════════════════════
// UNLOCK popup (centered takeover-lite over dimmed game)
// ════════════════════════════════════════════════════════════════
const Unlock = () => (
  <Frame>
    <div style={{position:'absolute', inset:0, background:'rgba(10,0,20,0.82)', zIndex:1}}></div>
    <div style={{position:'absolute', inset:0, background:`radial-gradient(ellipse at center, ${YELLOW}22 0%, transparent 60%)`, zIndex:1}}></div>
    {/* sparkles */}
    {[[20,28],[78,24],[26,70],[82,66],[50,16]].map(([x,y],i)=><span key={i} className="ac-star" style={{position:'absolute', left:`${x}%`, top:`${y}%`, fontFamily:'"Press Start 2P", monospace', fontSize:12, color:YELLOW, zIndex:2, animation:`acStar ${1.1+i*0.25}s ease-in-out infinite`}}>✦</span>)}
    <div style={{position:'relative', zIndex:6, flex:1, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', textAlign:'center', padding:'0 40px'}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:14, color:YELLOW, letterSpacing:4, textShadow:`0 0 10px ${YELLOW}aa`, marginBottom:30}}>PRESTASJON LÅST OPP</div>
      <div className="ac-pop" style={{animation:'acPop .6s cubic-bezier(.2,.9,.3,1.3) both'}}><Badge icon="bolt" tier="gold" size={170}/></div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:36, color:'#fff', letterSpacing:1, textShadow:`0 0 18px ${YELLOW}88`, margin:'26px 0 12px'}}>180!</div>
      <div style={{padding:'6px 14px', border:`2px solid ${GOLD}`, background:`${GOLD}12`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:GOLD, letterSpacing:2}}>GULL</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:19, color:'rgba(255,255,255,0.65)', letterSpacing:1, marginTop:18}}>Score maks 180 i X01</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:1, marginTop:16, textShadow:`0 0 8px ${CYAN}55`}}>18% av spillere har denne</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:17, color:'rgba(255,255,255,0.4)', letterSpacing:3, marginTop:30}}>TRYKK FOR Å FORTSETTE</div>
    </div>
  </Frame>
);

// slide-in toast variant (non-blocking, mid-game)
const Toast = () => (
  <Frame h={300}>
    <div style={{position:'absolute', inset:0, background:'rgba(10,0,20,0.4)'}}></div>
    <div className="ac-slide" style={{margin:'16px', padding:'14px 16px', border:`2px solid ${GOLD}`, background:'rgba(8,0,18,0.96)', boxShadow:`0 0 22px ${GOLD}55`, display:'flex', alignItems:'center', gap:14, position:'relative', zIndex:6, animation:'acSlide 4s ease-in-out infinite'}}>
      <Badge icon="star" tier="gold" size={58}/>
      <div style={{flex:1}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:YELLOW, letterSpacing:2, textShadow:`0 0 6px ${YELLOW}88`}}>PRESTASJON LÅST OPP</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:14, color:'#fff', letterSpacing:.5, marginTop:7}}>SHANGHAI!</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.55)', letterSpacing:.5, marginTop:5}}>Vinn med direkte Shanghai · GULL</div>
      </div>
    </div>
    <div style={{position:'absolute', left:16, right:16, top:120, fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.4)', letterSpacing:1, zIndex:6}}>↑ glir inn øverst ~3s, blokkerer ikke spillet · stables i kø ved flere</div>
  </Frame>
);

// ── concept / discussion card ───────────────────────────────────
const SpecCard = () => (
  <div style={{boxSizing:'border-box', width:680, height:1180, background:'#fffdf6', border:'1.5px solid rgba(0,0,0,0.14)', padding:'30px 34px', fontFamily:'"Inter", system-ui, sans-serif', display:'flex', flexDirection:'column', gap:14, overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>Konsept · til diskusjon</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:27, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Prestasjoner (achievements)</div>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Idé</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Badges låst opp av faktisk spill. <b style={{color:'#2a251f'}}>Ikke et eget menypunkt</b> — det bor i <b style={{color:'#2a251f'}}>statistikk-profilen</b> (som allerede er per spiller); «se alle» åpner full-oversikten som en under-visning der. Pluss en <b style={{color:'#2a251f'}}>popup</b> ved opplåsing (full ved kamp-slutt, toast midt i spill). Alt fra ModeStats/SavedPlayer — ingen ny scoring.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Eksempler → datakilde</div>
      <SpecRow zone="180! / Skarpskytter" val="X01 highestTurn · triplesHit" />
      <SpecRow zone="Checkout-konge" val="X01 checkouts · bestCheckout" />
      <SpecRow zone="Bullseye" val="bullsHit (25/50)" />
      <SpecRow zone="Shanghai!" val="Shanghai isInstantShanghai" />
      <SpecRow zone="Leiemorder / Overlevende" val="Killer kills · lives-tap" />
      <SpecRow zone="Comeback" val="Splitscore vinn etter halvering" />
      <SpecRow zone="Mester / Veteran" val="rating ≥ 1400 · gamesPlayed" />
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Tiers + sjeldenhet</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Bronse / sølv / gull for kumulative mål (10 / 50 / 200 checkouts); engangs-bragder (180, Shanghai) er gull direkte. Hver badge viser <b style={{color:'#2a251f'}}>sjeldenhet</b> som «X% har denne» — og <b style={{color:'#2a251f'}}>fargen</b> sier hvor sjelden (gull ≤10% · cyan ≤30% · dempet ellers), ingen tekst-merkelapp. <b style={{color:'#2a251f'}}>Engangs:</b> kan ikke låses opp flere ganger.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:8, textTransform:'uppercase', letterSpacing:0.5}}>Avgjort (standard — kan justeres)</div>
      {[
        ['Sjeldenhet-kilde','Lokalt nå (lagrede spillere på enheten) — globalt senere hvis/når backend.'],
        ['Omfang','~18 håndplukkede ved lansering + rom for skjulte/sjeldne badges.'],
        ['Popup-timing','Begge: toast straks midt i spill + oppsummering ved kamp-slutt.'],
        ['Belønning','Prestisje ved lansering; kosmetiske opplåsninger (rammer/temaer) som mulig utvidelse.'],
        ['Retro-telling','Start på null ved lansering (enkelt + rettferdig); import kan vurderes.'],
      ].map(([t,b])=>(
        <div key={t} style={{display:'flex', gap:11, padding:'8px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
          <div style={{flexShrink:0, width:96, fontFamily:'"JetBrains Mono", monospace', fontSize:12, fontWeight:700, color:'#7a4a2a'}}>{t}</div>
          <div style={{flex:1, fontFamily:'"Inter", sans-serif', fontSize:12.5, lineHeight:1.5, color:'#5a544a'}}>{b}</div>
        </div>
      ))}
    </div>
    <div style={{marginTop:'auto', padding:'12px 14px', background:'#dcefe1', border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, lineHeight:1.55, color:'#2a4a36'}}>
        <b>Låst:</b> integrert i statistikk (ikke eget menypunkt) · engangs · sjeldenhet vist via farge · lokal sjeldenhet · ~18 badges + skjulte · popup både midt i spill og ved kamp-slutt · prestisje først. Klar for bygg.
      </div>
    </div>
  </div>
);
const SpecRow = ({ zone, val }) => (
  <div style={{display:'flex', alignItems:'center', gap:10, padding:'7px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
    <div style={{flex:1, fontFamily:'"Inter", system-ui, sans-serif', fontSize:13, fontWeight:600, color:'#2a251f'}}>{zone}</div>
    <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11.5, color:'#5a544a'}}>{val}</div>
  </div>
);

// ── Canvas ──────────────────────────────────────────────────────
const AchievementsConcept = () => (
  <DCSection
    id="achievements"
    title="Prestasjoner — konsept (til diskusjon)"
    subtitle="Nytt: badges låst opp av faktisk spill (fra ModeStats/SavedPlayer). Bor i STATISTIKK-profilen (ingen eget menypunkt) — «se alle» åpner galleriet der. Hver badge viser sjeldenhet (% som har den) og kan låses opp én gang. Deler: oversikt-galleri, profil-integrasjon + «nærmest å låse opp», og UNLOCK (popup ved kamp-slutt + toast midt i spill).">
    <DCArtboard id="ach-overview" label="Oversikt · galleri" width={AC_W} height={AC_H}><Overview/></DCArtboard>
    <DCArtboard id="ach-profile" label="Profil-integrasjon (statistikk)" width={AC_W} height={AC_H}><ProfileIntegration/></DCArtboard>
    <DCArtboard id="ach-unlock" label="Unlock · popup (kamp-slutt)" width={AC_W} height={AC_H}><Unlock/></DCArtboard>
    <DCArtboard id="ach-toast" label="Unlock · toast (midt i spill)" width={AC_W} height={300}><Toast/></DCArtboard>
    <DCArtboard id="ach-spec" label="Konsept · datakilder + åpne spørsmål" width={680} height={1180}><SpecCard/></DCArtboard>
  </DCSection>
);
window.AchievementsConcept = AchievementsConcept;
