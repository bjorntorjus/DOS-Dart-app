// DOSSEDART — In-game sheets (⋯ MENU + manage players)
// The cockpit ⋯ MENU button opens a bottom sheet. MENU exists in code already
// (arcade-styled); the MANAGE-PLAYERS sheet behind "player overview" is still
// plain Material — so here's both as a matched pair of arcade bottom sheets
// over a dimmed game.
//   MENU    — resume · sound/video/memes/voice toggles · player overview · exit
//   PLAYERS — current players (remove, min 2) · add from saved players

const MS_W = 820, MS_H = 1180;

const YELLOW  = '#FFD200';
const MAGENTA = '#FF00AA';
const CYAN    = '#00E5FF';
const GREEN   = '#3DFF8E';
const RED      = '#FF3050';
const ORANGE  = '#FF7A00';
const BG      = '#0a0014';
const PANEL   = '#120826';
const PHOSPHOR= '#D9D2C2';

// ── icons (small arcade glyphs) ─────────────────────────────────
const SIcon = ({ name, color=CYAN, size=20 }) => {
  const p = { width:size, height:size, viewBox:'0 0 24 24', fill:'none', stroke:color, strokeWidth:2, strokeLinejoin:'round', strokeLinecap:'round' };
  switch(name){
    case 'sound':  return <svg {...p}><path d="M4 9v6h4l5 4V5L8 9z" fill={color} fillOpacity="0.25"/><path d="M17 8c1.5 1.5 1.5 6.5 0 8"/></svg>;
    case 'video':  return <svg {...p}><rect x="3" y="6" width="13" height="12" rx="1.5"/><path d="M16 10l5-3v10l-5-3z" fill={color} fillOpacity="0.25"/></svg>;
    case 'meme':   return <svg {...p}><circle cx="12" cy="12" r="9"/><circle cx="9" cy="10" r="1.2" fill={color} stroke="none"/><circle cx="15" cy="10" r="1.2" fill={color} stroke="none"/><path d="M8 14c1.4 1.6 6.6 1.6 8 0"/></svg>;
    case 'voice':  return <svg {...p}><rect x="9" y="3" width="6" height="11" rx="3" fill={color} fillOpacity="0.25"/><path d="M6 11a6 6 0 0 0 12 0M12 17v4"/></svg>;
    case 'board':  return <svg {...p}><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4"/><circle cx="12" cy="12" r="1" fill={color} stroke="none"/></svg>;
    case 'people': return <svg {...p}><circle cx="9" cy="8" r="3"/><path d="M3 20c0-3.3 2.7-5 6-5s6 1.7 6 5"/><path d="M16 6.5a3 3 0 0 1 0 5M21 20c0-2.5-1.4-4-3.5-4.6"/></svg>;
    case 'exit':   return <svg {...p}><path d="M14 4h4a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-4"/><path d="M3 12h11M10 8l-4 4 4 4"/></svg>;
    case 'add':    return <svg {...p}><circle cx="12" cy="12" r="9"/><path d="M12 8v8M8 12h8"/></svg>;
    case 'remove': return <svg {...p}><circle cx="12" cy="12" r="9"/><path d="M8 12h8"/></svg>;
    case 'play':   return <svg {...p}><path d="M7 5l12 7-12 7z" fill={color} fillOpacity="0.25"/></svg>;
    default: return <svg {...p}><circle cx="12" cy="12" r="9"/></svg>;
  }
};
const Avatar = ({ size=40, color=PHOSPHOR }) => (
  <div style={{width:size, height:size, borderRadius:'50%', background:'#1a0030', border:`2px solid ${color}`, display:'flex', alignItems:'flex-end', justifyContent:'center', flexShrink:0, overflow:'hidden'}}>
    <svg width={size*0.8} height={size*0.8} viewBox="0 0 24 24" style={{marginBottom:-1}}><circle cx="12" cy="9" r="4.2" fill={color} opacity="0.85"/><path d="M3.5 22c0-5 3.8-8 8.5-8s8.5 3 8.5 8z" fill={color} opacity="0.85"/></svg>
  </div>
);
const Pill = ({ on }) => (
  <div style={{width:48, height:25, borderRadius:13, border:`2px solid ${on?GREEN:'rgba(255,255,255,0.25)'}`, background:on?`${GREEN}1e`:'transparent', boxShadow:on?`0 0 10px ${GREEN}55`:'none', position:'relative', flexShrink:0}}>
    <div style={{position:'absolute', top:2, left:on?24:2, width:17, height:17, borderRadius:'50%', background:on?GREEN:'rgba(255,255,255,0.4)', boxShadow:on?`0 0 7px ${GREEN}`:'none'}}></div>
  </div>
);

// ── dimmed game backdrop ────────────────────────────────────────
const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
const Backdrop = ({ children }) => (
  <div style={{width:MS_W, height:MS_H, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', position:'relative', overflow:'hidden', display:'flex', flexDirection:'column', justifyContent:'flex-end'}}>
    {/* faint game behind */}
    <div style={{position:'absolute', top:0, left:0, right:0, padding:'14px 22px', borderBottom:`2px solid ${MAGENTA}66`, display:'flex', justifyContent:'space-between', opacity:0.4}}>
      <span style={{fontFamily:'"VT323", monospace', fontSize:16, color:CYAN}}>◀ EXIT</span>
      <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:YELLOW}}>X01 · 501 · D-OUT</span>
      <span style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)'}}>L 1/3 · RND 7</span>
    </div>
    <svg width="500" height="500" viewBox="0 0 500 500" style={{position:'absolute', left:'50%', top:'42%', transform:'translate(-50%,-50%)', opacity:0.07}}>
      <circle cx="250" cy="250" r="240" fill="none" stroke={PHOSPHOR} strokeWidth="2"/>
      <circle cx="250" cy="250" r="150" fill="none" stroke={PHOSPHOR} strokeWidth="1"/>
      {Array.from({length:20}).map((_,i)=>{ const a=(i/20)*2*Math.PI, x=250+Math.cos(a)*240, y=250+Math.sin(a)*240; return <line key={i} x1="250" y1="250" x2={x} y2={y} stroke={PHOSPHOR} strokeWidth="0.5"/>; })}
    </svg>
    <div style={{position:'absolute', inset:0, background:'rgba(10,0,20,0.74)', zIndex:1}}></div>
    <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}></div>
    <div style={{position:'relative', zIndex:6}}>{children}</div>
  </div>
);
const Sheet = ({ title, sub, children, onClose='FORTSETT' }) => (
  <div style={{background:PANEL, borderTop:`3px solid ${MAGENTA}`, boxShadow:`0 -6px 30px ${MAGENTA}44`}}>
    <div style={{width:46, height:5, borderRadius:3, background:'rgba(255,255,255,0.3)', margin:'10px auto 0'}}></div>
    <div style={{display:'flex', alignItems:'center', gap:12, padding:'14px 20px 12px'}}>
      <div style={{flex:1, minWidth:0}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:14, color:YELLOW, letterSpacing:2, textShadow:`0 0 6px ${YELLOW}66`}}>{title}</div>
        {sub && <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.5)', letterSpacing:1, marginTop:5}}>{sub}</div>}
      </div>
      <div style={{display:'flex', alignItems:'center', gap:8, padding:'8px 13px', border:`2px solid ${CYAN}`, background:`${CYAN}12`}}>
        <SIcon name="play" color={CYAN} size={14}/>
        <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:CYAN, letterSpacing:1}}>{onClose}</span>
      </div>
    </div>
    {children}
    <div style={{height:20}}></div>
  </div>
);

// ── MENU sheet ──────────────────────────────────────────────────
const ToggleRow = ({ icon, label, on }) => (
  <div style={{display:'flex', alignItems:'center', gap:14, padding:'13px 20px'}}>
    <div style={{width:30, display:'flex', justifyContent:'center'}}><SIcon name={icon} color={CYAN}/></div>
    <span style={{flex:1, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#fff', letterSpacing:1.5}}>{label}</span>
    <Pill on={on}/>
  </div>
);
const ActionRow = ({ icon, label, color='#fff', iconColor=CYAN }) => (
  <div style={{display:'flex', alignItems:'center', gap:14, padding:'15px 20px', borderTop:'1px solid rgba(255,255,255,0.07)'}}>
    <div style={{width:30, display:'flex', justifyContent:'center'}}><SIcon name={icon} color={iconColor}/></div>
    <span style={{flex:1, fontFamily:'"Press Start 2P", monospace', fontSize:11, color, letterSpacing:1.5}}>{label}</span>
    <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:`${color === '#fff' ? 'rgba(255,255,255,0.5)' : color}`}}>›</span>
  </div>
);
const MenuSheet = () => (
  <Backdrop>
    <Sheet title="MENY">
      <ToggleRow icon="sound" label="LYD" on/>
      <ToggleRow icon="video" label="VIDEO-HENDELSER" on/>
      <ToggleRow icon="meme" label="MEMES" on={false}/>
      <ToggleRow icon="voice" label="STEMME (TTS)" on/>
      <ActionRow icon="people" label="SPILLER-OVERSIKT" iconColor={CYAN}/>
      <ActionRow icon="exit" label="AVSLUTT KAMP" color={RED} iconColor={RED}/>
    </Sheet>
  </Backdrop>
);

// ── MANAGE PLAYERS sheet ────────────────────────────────────────
const CURRENT = [
  { name:'Jonas',   you:true, rating:1287, score:170, removed:false },
  { name:'Andreas', rating:1162, score:222, removed:false },
  { name:'Mia',     rating:1098, score:301, removed:false },
  { name:'Ola',     rating:1071, removed:true },
];
const AVAILABLE = [
  { name:'Sander', rating:1240 },
  { name:'Kari',   rating:1205 },
];
const activeCount = CURRENT.filter(p=>!p.removed).length;

const ManageSheet = () => (
  <Backdrop>
    <Sheet title="SPILLER-OVERSIKT" sub="Stilling i kampen · fjern eller legg til (min 2 aktive)">
      <div style={{padding:'0 20px'}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:8, color:'rgba(255,255,255,0.5)', letterSpacing:2, margin:'6px 0 4px'}}>I KAMPEN</div>
      </div>
      {CURRENT.map((p,i) => {
        const canRemove = !p.removed && activeCount > 2;
        const col = p.you?CYAN:PHOSPHOR;
        return (
          <div key={p.name} style={{display:'flex', alignItems:'center', gap:13, padding:'11px 20px', opacity:p.removed?0.45:1}}>
            <Avatar size={40} color={col}/>
            <div style={{flex:1, minWidth:0}}>
              <div style={{display:'flex', alignItems:'center', gap:7}}>
                <span style={{fontFamily:'"Inter", system-ui, sans-serif', fontWeight:700, fontSize:15, color:p.you?CYAN:'#fff'}}>{p.name}</span>
                {p.you && <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:7, color:CYAN, letterSpacing:1}}>DEG</span>}
              </div>
              <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:1, marginTop:2}}>{p.removed?'fjernet fra kampen':`rating ${p.rating}`}</div>
            </div>
            {!p.removed && <div style={{textAlign:'right', marginRight:2}}>
              <div style={{fontFamily:'"VT323", monospace', fontSize:12, color:'rgba(255,255,255,0.4)', letterSpacing:1}}>IGJEN</div>
              <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:16, color:p.you?CYAN:'#fff', textShadow:p.you?`0 0 6px ${CYAN}88`:'none'}}>{p.score}</div>
            </div>}
            {!p.removed && (
              <div style={{display:'flex', alignItems:'center', justifyContent:'center', width:42, height:42, border:`2px solid ${canRemove?RED:'rgba(255,255,255,0.15)'}`, background:canRemove?`${RED}10`:'transparent'}}>
                <SIcon name="remove" color={canRemove?RED:'rgba(255,255,255,0.3)'} size={18}/>
              </div>
            )}
          </div>
        );
      })}
      <div style={{height:1, background:'rgba(255,255,255,0.08)', margin:'8px 20px'}}></div>
      <div style={{padding:'0 20px'}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:8, color:'rgba(255,255,255,0.5)', letterSpacing:2, margin:'4px 0 6px'}}>LEGG TIL FRA LAGREDE</div>
      </div>
      {AVAILABLE.map(p => (
        <div key={p.name} style={{display:'flex', alignItems:'center', gap:13, padding:'11px 20px'}}>
          <Avatar size={40} color={PHOSPHOR}/>
          <div style={{flex:1, minWidth:0}}>
            <div style={{fontFamily:'"Inter", system-ui, sans-serif', fontWeight:700, fontSize:15, color:'#fff'}}>{p.name}</div>
            <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:1, marginTop:2}}>rating {p.rating}</div>
          </div>
          <div style={{display:'flex', alignItems:'center', gap:8, padding:'8px 12px', border:`2px solid ${GREEN}`, background:`${GREEN}10`}}>
            <SIcon name="add" color={GREEN} size={16}/>
            <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:GREEN, letterSpacing:1}}>LEGG TIL</span>
          </div>
        </div>
      ))}
    </Sheet>
  </Backdrop>
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
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>Implementasjon · in-game sheets</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:27, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>⋯ Meny + bytt spillere</div>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Hva</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>To bunn-ark over den dimmede cockpiten. <b style={{color:'#2a251f'}}>MENY</b> finnes alt arcade-stilt (DossedartMenuSheet) — polert her. <b style={{color:'#2a251f'}}>«Spiller-oversikt» og «bytt spillere» er slått sammen til én</b>: oversikten viser stillingen i kampen OG lar deg fjerne/legge til — erstatter Material-arket (mid_game_player_sheet.dart).</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Innhold → kilde</div>
      <SpecRow zone="Toggles (lyd/video/memes/tts)" val="AppSettings · service-singletons" hex={GREEN}/>
      <SpecRow zone="Spiller-oversikt (= bytt)" val="stilling + showMidGamePlayerSheet" hex={CYAN}/>
      <SpecRow zone="Fjern (min 2 aktive)" val="onRemove · canRemove" hex={RED}/>
      <SpecRow zone="Legg til fra lagrede" val="PlayerStorage.loadPlayers · onAdd" hex={GREEN}/>
      <SpecRow zone="Avslutt kamp" val="onExit (bekreft → hjem)" hex={RED}/>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:8, textTransform:'uppercase', letterSpacing:0.5}}>Bygg + best practice</div>
      {[
        ['1','Arcade-ark','PANEL #120826, magenta topp-kant + glød, grab-handle, skarpe hjørner. Erstatt Material showModalBottomSheet-stilen i mid_game_player_sheet.dart.'],
        ['2','Toggles = grønn pill','Lik settings: grønn pill av/på. Flips kaller onXChanged (service + persistert) som i dag.'],
        ['3','Fjern-regel','FJERN deaktiveres når aktive ≤ 2 (canRemove). Fjernet spiller dimmes + «fjernet fra kampen». Nye starter med modus-riktig score (onAdd).'],
        ['4','Fulle navn + deg=cyan','Aldri forkortelser. Innlogget spiller cyan. Lagrede sortert alfabetisk, allerede-med skjules.'],
        ['5','Lukk','FORTSETT (▸) lukker arket og returnerer til spillet. Avslutt kamp bekreftes før exit.'],
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
        <b>Konsistens:</b> samme tokens + CRT-chrome som cockpit-ene. Arket deler stil med settings-kontrollene (grønn pill, cyan accent, magenta ramme).
      </div>
    </div>
  </div>
);

// ── Canvas ──────────────────────────────────────────────────────
const InGameSheets = () => (
  <DCSection
    id="ingame-sheets"
    title="In-game sheets — ⋯ meny + bytt spillere"
    subtitle="Bunn-ark over den dimmede cockpiten. MENY (alt arcade-stilt i kode) polert. «Spiller-oversikt» og «bytt spillere» er slått sammen til én: se stillingen + fjern (min 2 aktive) eller legg til fra lagrede. Erstatter dagens Material-ark. Samme tokens som settings.">
    <DCArtboard id="ms-menu" label="⋯ MENY" width={MS_W} height={MS_H}><MenuSheet/></DCArtboard>
    <DCArtboard id="ms-players" label="SPILLER-OVERSIKT (se + bytt)" width={MS_W} height={MS_H}><ManageSheet/></DCArtboard>
    <DCArtboard id="ms-spec" label="Implementasjon · spec + kilder" width={680} height={1180}><SpecCard/></DCArtboard>
  </DCSection>
);
window.InGameSheets = InGameSheets;
