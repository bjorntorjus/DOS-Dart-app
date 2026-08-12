// DOSSEDART — 1UP cockpit · lives / beat-the-target
// ───────────────────────────────────────────────────────────────
// Reuses the DOSSEDART cockpit skeleton verbatim: Frame chrome + scanlines,
// TopBar (EXIT · title · round), the LOCKED CRT "BALANSERT" board (760 @
// top 340), MISS corners and the ActionBar (UNDO · MISS · MENU). Nothing in
// the skeleton is redesigned.
//
// What is NEW for 1UP (design effort here):
//   • active-card content — big  BEAT <target>  as the primary number,
//     running turnTotal + NEED <n> MORE line
//   • LIFE PIPS (hearts) on every player card, in the carousel
//   • SAFE state (green) + CAN'T-BEAT state (red) mid-turn
//   • free-opening-throw state (SET THE TARGET, no target yet)
//   • life-lost signature moment (a pip cracking)
//   • last-life persistent danger styling
//   • elimination + winner moments
// UI strings are English (Norwegian-string guard). Terminology: 1UP.

const OU_W = 820, OU_H = 1180;

const YELLOW='#FFD200', MAGENTA='#FF00AA', CYAN='#00E5FF', GREEN='#3DFF8E',
      RED='#FF3050', ORANGE='#FF7A00', BG='#0a0014', SURFACE='#1a0030',
      PHOSPHOR='#D9D2C2', PURPLE='#7B3FFF', LIME='#C6FF3C';

// ════════════════════════════════════════════════════════════════
// LOCKED CRT "BALANSERT" BOARD — copied verbatim from gotcha.jsx.
// ════════════════════════════════════════════════════════════════
const OU_SECTORS = [20,1,18,4,13,6,10,15,2,17,3,19,7,16,8,11,14,9,12,5];
const OU_DBULL=0.06, OU_BULL=0.14, OU_SINGLE_I=0.46, OU_TRIPLE=0.64, OU_SINGLE_O=0.86, OU_DOUBLE=1.0, OU_NUM=1.06;
const OU_TAU=Math.PI*2, OU_SEG=OU_TAU/20;
const OU_BOARD = { surround:'#05000e', base:'#05000e', darkSingle:'#190b32', lightSingle:'#3c2472',
  ringDark:'#e637a8', ringLight:'#2fc4dd', bullOuter:'#FFD200', bullStroke:'#FF7A00', bullInner:'#FF3050', num:'#fff' };

function ouWedge(cx,cy,rIn,rOut,a1,a2){
  const px=(r,a)=>cx+r*Math.cos(a), py=(r,a)=>cy+r*Math.sin(a);
  const large=(a2-a1)>Math.PI?1:0;
  return `M ${px(rIn,a1)} ${py(rIn,a1)} L ${px(rOut,a1)} ${py(rOut,a1)} A ${rOut} ${rOut} 0 ${large} 1 ${px(rOut,a2)} ${py(rOut,a2)} L ${px(rIn,a2)} ${py(rIn,a2)} A ${rIn} ${rIn} 0 ${large} 0 ${px(rIn,a1)} ${py(rIn,a1)} Z`;
}
function ouBoardSVG(size, o){
  const cx=size/2, cy=size/2, R=size*0.40;
  let s=`<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" style="display:block">`;
  s+=`<circle cx="${cx}" cy="${cy}" r="${R*1.14}" fill="${o.surround}"/>`;
  s+=`<circle cx="${cx}" cy="${cy}" r="${R*OU_DOUBLE}" fill="${o.base}"/>`;
  for(let i=0;i<20;i++){
    const a1=-Math.PI/2+i*OU_SEG-OU_SEG/2, a2=a1+OU_SEG;
    const isDark=(i%2===0);
    const single=isDark?o.darkSingle:o.lightSingle;
    const ring=isDark?o.ringDark:o.ringLight;
    s+=`<path d="${ouWedge(cx,cy,OU_BULL*R,OU_SINGLE_I*R,a1,a2)}" fill="${single}"/>`;
    s+=`<path d="${ouWedge(cx,cy,OU_SINGLE_I*R,OU_TRIPLE*R,a1,a2)}" fill="${ring}"/>`;
    s+=`<path d="${ouWedge(cx,cy,OU_TRIPLE*R,OU_SINGLE_O*R,a1,a2)}" fill="${single}"/>`;
    s+=`<path d="${ouWedge(cx,cy,OU_SINGLE_O*R,OU_DOUBLE*R,a1,a2)}" fill="${ring}"/>`;
  }
  s+=`<circle cx="${cx}" cy="${cy}" r="${OU_BULL*R}" fill="${o.bullOuter}" stroke="${o.bullStroke}" stroke-width="2.5"/>`;
  s+=`<circle cx="${cx}" cy="${cy}" r="${OU_DBULL*R}" fill="${o.bullInner}"/>`;
  const fs=size*0.04;
  OU_SECTORS.forEach((n,i)=>{ const c=-Math.PI/2+i*OU_SEG, x=cx+Math.cos(c)*OU_NUM*R, y=cy+Math.sin(c)*OU_NUM*R; s+=`<text x="${x}" y="${y+fs*0.36}" font-family="'Press Start 2P',monospace" font-size="${fs}" fill="${o.num}" text-anchor="middle">${n}</text>`; });
  return s+`</svg>`;
}
const OUBoard = ({ size=300 }) => (
  <div style={{position:'relative', width:size, height:size}}>
    <div style={{filter:`drop-shadow(0 0 6px ${MAGENTA}44) drop-shadow(0 0 3px ${CYAN}33)`}}
         dangerouslySetInnerHTML={{__html: ouBoardSVG(size, OU_BOARD)}}/>
    <div style={{position:'absolute', inset:0, pointerEvents:'none', background:'repeating-linear-gradient(0deg,rgba(0,0,0,0) 0px,rgba(0,0,0,0) 3px,rgba(0,0,0,0.26) 4px,rgba(0,0,0,0) 5px)'}}/>
    <div style={{position:'absolute', inset:0, pointerEvents:'none', borderRadius:'50%', background:'radial-gradient(ellipse 56% 42% at 50% 28%,rgba(255,255,255,0.10),transparent 60%)'}}/>
    <div style={{position:'absolute', inset:0, pointerEvents:'none', borderRadius:'50%', boxShadow:'inset 0 0 60px 10px rgba(0,0,0,0.7)'}}/>
  </div>
);

// ── shell chrome — identical pattern to the X01 / Gotcha cockpit ─
const ouScan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
const OUFrame = ({ children }) => (
  <div style={{width:OU_W, height:OU_H, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
    <div style={{position:'absolute', inset:0, backgroundImage:ouScan, pointerEvents:'none', zIndex:5}}></div>
    <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
    {children}
  </div>
);
const OUTopBar = ({ alive, round }) => (
  <div style={{padding:'14px 22px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:14, position:'relative', zIndex:6}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:2}}>◀ EXIT</div>
    <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:12, color:YELLOW, letterSpacing:2, textShadow:`0 0 6px ${YELLOW}88`}}>🕹️ 1UP</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>{alive} ALIVE</div>
  </div>
);
const OUActionBar = () => (
  <div style={{position:'absolute', left:0, right:0, bottom:0, padding:'12px 16px 16px', background:'#000', borderTop:`2px solid ${YELLOW}`, display:'flex', gap:10, zIndex:6}}>
    <div style={{flex:1, padding:'14px', border:`2px solid ${MAGENTA}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#fff', letterSpacing:1.5, textAlign:'center'}}>↶ UNDO</div>
    <div style={{flex:2, padding:'14px', background:ORANGE, border:`2px solid #fff`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:BG, letterSpacing:2, textAlign:'center', boxShadow:`0 0 16px ${ORANGE}8c`}}>✗ MISS</div>
    <div style={{flex:1, padding:'14px', border:`2px solid ${CYAN}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, letterSpacing:1.5, textAlign:'center'}}>⋯ MENU</div>
  </div>
);
const OUMissCorner = ({ pos }) => (
  <div style={{position:'absolute', ...pos, fontFamily:'"Press Start 2P", monospace', fontSize:9, color:MAGENTA, opacity:0.3, letterSpacing:1, pointerEvents:'none'}}>✗ MISS</div>
);

// ════════════════════════════════════════════════════════════════
// LIFE PIPS — the new persistent element on every player card.
// filled = live heart (player colour + glow); spent = dim outline;
// cracking = the just-lost heart at the life-lost moment.
// ════════════════════════════════════════════════════════════════
const LifePips = ({ lives, max, color, size=17, cracking=false }) => (
  <div style={{display:'flex', gap:4, alignItems:'center'}}>
    {Array.from({length:max}).map((_,i)=>{
      const live = i < lives;
      const crack = cracking && i === lives; // the pip breaking right now
      return (
        <span key={i} style={{
          fontFamily:'"VT323", monospace', fontSize:size, lineHeight:1,
          color: live ? color : crack ? RED : 'rgba(255,255,255,0.18)',
          textShadow: live ? `0 0 6px ${color}` : crack ? `0 0 10px ${RED}` : 'none',
          animation: crack ? 'ouCrack 0.5s ease-out' : 'none',
        }}>{live ? '♥' : crack ? '💔' : '♡'}</span>
      );
    })}
  </div>
);

// ════════════════════════════════════════════════════════════════
// ACTIVE CARD — big BEAT<target> + NEED line, mode-specific states.
// mode: 'open' | 'default' | 'safe' | 'cant' | 'lastlife'
// ════════════════════════════════════════════════════════════════
const OUActiveCard = ({ p }) => {
  const c = p.accent;
  const danger = p.mode === 'cant' || p.mode === 'lastlife';
  const safe = p.mode === 'safe';
  const open = p.mode === 'open';
  // frame colour reflects the state
  const frame = safe ? GREEN : danger ? RED : c;
  const need = p.target != null ? Math.max(0, p.target - p.turnTotal) : null;

  return (
    <div style={{position:'relative', border:`3px solid ${frame}`,
                 background:`linear-gradient(180deg, ${frame}1c 0%, ${frame}05 100%)`,
                 boxShadow:`0 0 20px ${frame}55`, padding:'14px 18px 16px',
                 animation: p.mode==='lastlife' ? 'ouDangerPulse 1.1s infinite' : 'none'}}>
      <div style={{position:'absolute', top:-9, left:16, padding:'3px 9px', background:frame, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:9, letterSpacing:1.5, boxShadow:`0 0 8px ${frame}aa`}}>▶ NOW THROWING</div>
      {p.variant && <div style={{position:'absolute', top:-9, right:16, padding:'3px 9px', background:BG, color:LIME, border:`2px solid ${LIME}`, fontFamily:'"Press Start 2P", monospace', fontSize:8, letterSpacing:1}}>{p.variant==='best' ? `BEAT THE BEST · R${p.roundLabel||''}` : 'BEAT THE LAST'}</div>}

      {/* header row: avatar · name · lives */}
      <div style={{display:'flex', alignItems:'center', gap:13, marginTop:3}}>
        <div style={{width:48, height:48, background:BG, border:`3px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:13, color:c, textShadow:`0 0 8px ${c}aa`, flexShrink:0, boxShadow:`0 0 12px ${c}55`}}>{p.handle}</div>
        <div style={{flex:1, minWidth:0}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:16, color:'#fff', letterSpacing:2, lineHeight:1}}>{p.name.toUpperCase()}</div>
          <div style={{marginTop:8}}><LifePips lives={p.lives} max={p.maxLives} color={p.mode==='lastlife'?RED:c}/></div>
        </div>
        {p.mode==='lastlife' && <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:RED, letterSpacing:1, textShadow:`0 0 8px ${RED}`, textAlign:'right'}}>LAST<br/>LIFE</div>}
      </div>

      {/* primary line: BEAT <target>  OR  SET THE TARGET / SAFE / CAN'T BEAT */}
      <div style={{marginTop:14, display:'flex', alignItems:'flex-end', gap:16}}>
        <div style={{flex:1, minWidth:0}}>
          {open ? (
            <React.Fragment>
              <div style={{fontFamily:'"VT323", monospace', fontSize:17, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>{p.variant==='best'?'FIRST THROW · NEW ROUND':'FREE THROW · NO TARGET'}</div>
              <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:26, color:LIME, letterSpacing:1, textShadow:`0 0 12px ${LIME}aa`, marginTop:6, lineHeight:1.1}}>{p.variant==='best'?<React.Fragment>SET THE<br/>ROUND TARGET</React.Fragment>:<React.Fragment>SET THE<br/>TARGET</React.Fragment>}</div>
            </React.Fragment>
          ) : safe ? (
            <React.Fragment>
              <div style={{display:'flex', alignItems:'center', gap:8}}>
                <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:30, color:GREEN, letterSpacing:1, textShadow:`0 0 16px ${GREEN}`}}>SAFE</span>
                <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:22, color:GREEN}}>✓</span>
              </div>
              <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.7)', letterSpacing:1, marginTop:6}}>NEW TARGET · <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:16, color:YELLOW}}>{p.turnTotal}</span> <span style={{color:'rgba(255,255,255,0.4)'}}>· building…</span></div>
            </React.Fragment>
          ) : (
            <React.Fragment>
              <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:danger?RED:'rgba(255,255,255,0.6)', letterSpacing:2}}>BEAT</div>
              <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:62, color:danger?RED:'#fff', letterSpacing:-2, lineHeight:0.95, marginTop:4, textShadow:`0 0 18px ${danger?RED:c}88`}}>{p.target}</div>
            </React.Fragment>
          )}
        </div>

        {/* running total block */}
        <div style={{textAlign:'right', flexShrink:0, paddingBottom:4}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.5)', letterSpacing:1}}>THIS TURN</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:38, color:safe?GREEN:c, lineHeight:1, textShadow:`0 0 14px ${(safe?GREEN:c)}aa`, letterSpacing:-1, marginTop:4}}>{p.turnTotal}</div>
          <div style={{display:'flex', gap:5, marginTop:8, justifyContent:'flex-end'}}>
            {[0,1,2].map(i=>(
              <div key={i} style={{width:9, height:9, background:i<p.dartIdx?c:'transparent', border:`2px solid ${c}`, boxShadow:i<p.dartIdx?`0 0 6px ${c}aa`:'none'}}></div>
            ))}
          </div>
        </div>
      </div>

      {/* status line: NEED n MORE · SAFE by · CAN'T BEAT · SET */}
      <div style={{marginTop:13, padding:'9px 13px', display:'flex', alignItems:'center', gap:10,
                   background: safe?`${GREEN}18`:danger?`${RED}18`:'rgba(255,255,255,0.05)',
                   border:`2px solid ${safe?GREEN:danger?RED:'rgba(255,255,255,0.14)'}`}}>
        {open && <span style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:1}}>▸ YOUR 3-DART TOTAL SETS THE BAR FOR EVERYONE</span>}
        {p.mode==='default' && <React.Fragment>
          <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:YELLOW, letterSpacing:1, textShadow:`0 0 6px ${YELLOW}88`}}>NEED {need} MORE</span>
          <span style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.45)'}}>· {3-p.dartIdx} dart{3-p.dartIdx!==1?'s':''} left</span>
        </React.Fragment>}
        {safe && <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:GREEN, letterSpacing:1, textShadow:`0 0 6px ${GREEN}`}}>BEAT {p.target} · REMAINING DARTS PAD THE NEW TARGET</span>}
        {p.mode==='cant' && <React.Fragment>
          <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:RED, letterSpacing:1, textShadow:`0 0 8px ${RED}`}}>CAN'T BEAT</span>
          <span style={{fontFamily:'"VT323", monospace', fontSize:17, color:'#ff8fa6', letterSpacing:1}}>· LIFE AT RISK · need {need}, max {60*(3-p.dartIdx)}</span>
        </React.Fragment>}
        {p.mode==='lastlife' && <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:RED, letterSpacing:1, textShadow:`0 0 8px ${RED}`}}>NEED {need} MORE · MISS = ELIMINATED</span>}
      </div>
    </div>
  );
};

// ── peek card (carousel neighbour) — compact, shows lives + total ─
const OUPeekCard = ({ p, side }) => {
  const dead = p.eliminated;
  const c = dead ? 'rgba(255,255,255,0.25)' : p.accent;
  return (
    <div style={{width:96, flexShrink:0, border:`2px solid ${dead?'rgba(255,255,255,0.14)':c+'88'}`,
                 background: dead?'rgba(255,255,255,0.02)':`${c}0d`, padding:'11px 9px',
                 opacity: dead?0.5:0.82, position:'relative',
                 [side==='left'?'marginRight':'marginLeft']:0}}>
      {dead && <div style={{position:'absolute', top:6, right:7, fontSize:13}}>💀</div>}
      <div style={{width:32, height:32, background:BG, border:`2px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:9, color:c, margin:'0 auto'}}>{p.handle}</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'#fff', textAlign:'center', marginTop:6, letterSpacing:1, opacity:dead?0.6:1}}>{p.name.toUpperCase()}</div>
      <div style={{display:'flex', justifyContent:'center', marginTop:6}}>
        {dead ? <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:8, color:RED, letterSpacing:1}}>OUT</span>
              : <LifePips lives={p.lives} max={p.maxLives} color={c} size={13}/>}
      </div>
    </div>
  );
};

// ── carousel: left peek · active · right peek · pills ────────────
const OUCarousel = ({ s }) => (
  <div style={{padding:'14px 14px 0', position:'relative', zIndex:6}}>
    <div style={{display:'flex', alignItems:'stretch', gap:10}}>
      {s.left ? <OUPeekCard p={s.left} side="left"/> : <div style={{width:96, flexShrink:0}}/>}
      <div style={{flex:1, minWidth:0}}><OUActiveCard p={s.active}/></div>
      {s.right ? <OUPeekCard p={s.right} side="right"/> : <div style={{width:96, flexShrink:0}}/>}
    </div>
    <div style={{display:'flex', justifyContent:'center', gap:7, marginTop:11}}>
      {s.pills.map((on,i)=>(
        <div key={i} style={{width:on==='active'?22:8, height:8, borderRadius:4,
          background: on==='active'?s.active.accent: on==='dead'?'rgba(255,255,255,0.16)':'rgba(255,255,255,0.4)',
          boxShadow: on==='active'?`0 0 6px ${s.active.accent}`:'none'}}/>
      ))}
    </div>
  </div>
);

// ── full-frame moment overlay (life lost / elimination / winner) ─
const OUOverlay = ({ children, tint }) => (
  <div style={{position:'absolute', inset:0, zIndex:8, display:'flex', alignItems:'center', justifyContent:'center',
               background:`radial-gradient(ellipse at center, ${tint}22 0%, rgba(5,0,14,0.86) 70%)`, backdropFilter:'blur(2px)'}}>
    {children}
  </div>
);

// ════════════════════════════════════════════════════════════════
// COCKPIT — skeleton unchanged; carousel + board + action bar.
// ════════════════════════════════════════════════════════════════
const OUCockpit = ({ s }) => (
  <OUFrame>
    <OUTopBar alive={s.alive} round={s.round}/>
    <OUCarousel s={s}/>
    <div style={{position:'absolute', left:0, right:0, top:392, bottom:66, display:'flex', alignItems:'center', justifyContent:'center', zIndex:3}}>
      <div style={{position:'absolute', width:700, height:700, borderRadius:'50%', boxShadow:`0 0 70px ${MAGENTA}3a`, pointerEvents:'none'}}></div>
      <OUMissCorner pos={{top:6, left:18}}/>
      <OUMissCorner pos={{top:6, right:18}}/>
      <OUMissCorner pos={{bottom:6, left:18}}/>
      <OUMissCorner pos={{bottom:6, right:18}}/>
      <OUBoard size={720}/>
    </div>
    {s.overlay==='lifelost' && (
      <OUOverlay tint={RED}>
        <div style={{textAlign:'center'}}>
          <div style={{fontSize:60, animation:'ouCrack 0.6s ease-out'}}>💔</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:34, color:RED, letterSpacing:2, textShadow:`0 0 20px ${RED}`, marginTop:14}}>−1 LIFE</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:24, color:'#fff', letterSpacing:2, marginTop:12}}>{s.momentName} FAILED TO BEAT {s.momentTarget}</div>
          <div style={{marginTop:16, display:'flex', justifyContent:'center'}}><LifePips lives={1} max={3} color={RED} size={30} cracking/></div>
        </div>
      </OUOverlay>
    )}
    {s.overlay==='eliminated' && (
      <OUOverlay tint={RED}>
        <div style={{textAlign:'center'}}>
          <div style={{fontSize:64}}>💀</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:36, color:RED, letterSpacing:3, textShadow:`0 0 22px ${RED}`, marginTop:12}}>ELIMINATED</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:26, color:'#fff', letterSpacing:2, marginTop:14}}>{s.momentName} · OUT OF LIVES</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:YELLOW, letterSpacing:2, marginTop:16, textShadow:`0 0 8px ${YELLOW}88`}}>4TH PLACE</div>
        </div>
      </OUOverlay>
    )}
    {s.overlay==='winner' && (
      <OUOverlay tint={YELLOW}>
        <div style={{textAlign:'center'}}>
          <div style={{fontSize:34, letterSpacing:6, color:YELLOW}}>★ ★ ★</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:52, color:YELLOW, letterSpacing:2, textShadow:`0 0 26px ${YELLOW}, 5px 5px 0 ${MAGENTA}`, marginTop:14, lineHeight:1.1}}>1UP!</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:20, color:'#fff', letterSpacing:2, marginTop:18}}>{s.momentName} WINS</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:22, color:CYAN, letterSpacing:2, marginTop:10}}>LAST PLAYER STANDING</div>
          <div style={{marginTop:16, display:'flex', justifyContent:'center'}}><LifePips lives={2} max={3} color={YELLOW} size={30}/></div>
        </div>
      </OUOverlay>
    )}
    <OUActionBar/>
  </OUFrame>
);

// ── scenarios ────────────────────────────────────────────────────
const OUP = (o) => ({ name:'Jonas', handle:'JON', accent:CYAN, lives:3, maxLives:3, target:87, turnTotal:0, dartIdx:1, mode:'default', variant:'last', ...o });
const peek = (name, handle, accent, lives, opts={}) => ({ name, handle, accent, lives, maxLives:3, ...opts });

const KARI = ['Kari','KAR',MAGENTA], PER = ['Per','PER',GREEN], MIA = ['Mia','MIA',YELLOW];

const OU_STATES = {
  open: { alive:4, round:1,
    active: OUP({ mode:'open', target:null, turnTotal:60, dartIdx:2 }),
    left: peek(...KARI,3), right: peek(...PER,3),
    pills:['n','active','n','n'] },
  bestFree: { alive:4, round:3,
    active: OUP({ mode:'open', target:null, turnTotal:26, dartIdx:1, variant:'best', roundLabel:'3' }),
    left: peek(...KARI,3), right: peek(...PER,2),
    pills:['n','active','n','n'] },
  default: { alive:4, round:3,
    active: OUP({ mode:'default', target:87, turnTotal:42, dartIdx:1 }),
    left: peek(...KARI,3), right: peek(...PER,2),
    pills:['n','active','n','n'] },
  safe: { alive:4, round:3,
    active: OUP({ mode:'safe', target:87, turnTotal:92, dartIdx:2 }),
    left: peek(...KARI,3), right: peek(...PER,2),
    pills:['n','active','n','n'] },
  cant: { alive:4, round:5,
    active: OUP({ mode:'cant', target:145, turnTotal:30, dartIdx:2, lives:2 }),
    left: peek(...MIA,1), right: peek(...KARI,3),
    pills:['n','active','n','dead'] },
  lastlife: { alive:3, round:6,
    active: OUP({ name:'Per', handle:'PER', accent:GREEN, mode:'lastlife', target:118, turnTotal:71, dartIdx:2, lives:1 }),
    left: peek(...KARI,2), right: peek(...MIA,3),
    pills:['n','active','n','dead'] },
  lifelost: { alive:3, round:6, overlay:'lifelost', momentName:'PER', momentTarget:118,
    active: OUP({ name:'Per', handle:'PER', accent:GREEN, mode:'cant', target:118, turnTotal:71, dartIdx:3, lives:1 }),
    left: peek(...KARI,2), right: peek(...MIA,3),
    pills:['n','active','n','dead'] },
  eliminated: { alive:2, round:7, overlay:'eliminated', momentName:'PER',
    active: OUP({ name:'Per', handle:'PER', accent:GREEN, mode:'cant', target:118, turnTotal:71, dartIdx:3, lives:0 }),
    left: peek(...KARI,2), right: peek('Mia','MIA',YELLOW,3),
    pills:['n','active','dead','dead'] },
  winner: { alive:1, round:9, overlay:'winner', momentName:'JONAS',
    active: OUP({ mode:'default', target:120, turnTotal:120, dartIdx:3, lives:2 }),
    left: null, right: null,
    pills:['active','dead','dead','dead'] },
};

// ════════════════════════════════════════════════════════════════
// SPEC CARD
// ════════════════════════════════════════════════════════════════
const OUSpecRow = ({ zone, val, hex }) => (
  <div style={{display:'flex', alignItems:'center', gap:10, padding:'7px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
    {hex && <div style={{width:14, height:14, background:hex, border:'1px solid rgba(0,0,0,0.25)', flexShrink:0}}/>}
    <div style={{flex:1, fontFamily:'"Inter", system-ui, sans-serif', fontSize:13, fontWeight:600, color:'#2a251f'}}>{zone}</div>
    <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:12, color:'#5a544a'}}>{val}</div>
  </div>
);
const OUSpecCard = () => (
  <div style={{boxSizing:'border-box', width:680, height:1300, background:'#fffdf6', border:'1.5px solid rgba(0,0,0,0.14)', padding:'30px 34px', fontFamily:'"Inter", system-ui, sans-serif', display:'flex', flexDirection:'column', gap:14, overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>1UP · cockpit · fasit</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:26, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Liv, mål og BEAT — samme skjelett, nytt kort</div>
    </div>
    <div style={{padding:'12px 14px', background:'#dcefe1', border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a4a36', marginBottom:4}}>Uendret (gjenbruk)</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#2a4a36', lineHeight:1.5}}>Cockpit-skjelettet er urørt: <b>Frame + scanlines</b>, <b>TopBar</b>, den låste <b>CRT-tavlen</b>, MISS-hjørnene og <b>ActionBar (UNDO · MISS · MENU)</b>. Spillerkarusellen (aktivt kort + peek + pills) beholder mønsteret sitt. 1UP bytter kun <b>innholdet</b> i det aktive kortet.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Nye elementer</div>
      <OUSpecRow zone="BEAT <target> — primærtall + NEED n MORE" val="target − turnTotal" hex={CYAN}/>
      <OUSpecRow zone="LIFE PIPS (♥) på alle spillerkort" val="1 / 3 / 5 · setup" hex={RED}/>
      <OUSpecRow zone="SAFE — turnTotal >= target (tie = success)" val="grønn, bygger mål" hex={GREEN}/>
      <OUSpecRow zone="CAN'T BEAT — need > 60×dart igjen" val="rød · life at risk" hex={RED}/>
      <OUSpecRow zone="Free throw — SET THE TARGET (spillstart / hver runde i BEST)" val="intet mål" hex={LIME}/>
      <OUSpecRow zone="Variant — BEAT THE LAST / BEAT THE BEST" val="chips · setup" hex={LIME}/>
      <OUSpecRow zone="Random order — shuffle hver runde" val="toggle · setup" hex={LIME}/>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>8 states</div>
      {[
        ['1 · Free throw','Intet mål — SET THE TARGET. Spillstart (BEAT THE LAST) / hver runde-start (BEAT THE BEST). Ingen fail mulig.'],
        ['2 · Default','BEAT 87 stort + NEED n MORE. Spillerfarge på ramme.'],
        ['3 · SAFE','turnTotal >= target (tie = success): grønt kort, «NEW TARGET n · building». Resten padder.'],
        ['4 · CAN\'T BEAT','need > maks mulig med darts igjen → rødt, «LIFE AT RISK». Kaster fortsatt ut turen.'],
        ['5 · Life lost','Signaturøyeblikk: pip sprekker (💔), −1 LIFE-overlay.'],
        ['6 · Last life','Vedvarende fare-styling på kortet (rød puls, LAST LIFE, pips røde).'],
        ['7 · Elimination','0 liv → ELIMINATED-overlay + plassering. Peek-kort blir dimmet/💀, pill grå.'],
        ['8 · Winner','Siste spiller igjen → 1UP!-overlay.'],
      ].map(([t,b])=>(
        <div key={t} style={{padding:'7px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
          <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, fontWeight:700, color:'#2a251f'}}>{t}</div>
          <div style={{fontFamily:'"Inter", sans-serif', fontSize:11.5, lineHeight:1.4, color:'#5a544a', marginTop:2}}>{b}</div>
        </div>
      ))}
    </div>
    <div style={{marginTop:'auto', padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, lineHeight:1.55, color:'#5a544a'}}>
        <b>Farge-roller:</b> spillerfarge = aktiv ramme + total · grønn = SAFE · rød/💔 = fare/tap · gul = mål-label + winner · <b style={{color:'#6a8f14'}}>lime = 1UP-merkevare</b> (nytt token, se palett-kort). Alle UI-strenger engelske (norsk-guard). <b>Tie = success</b> (turnTotal ≥ target trygt). BEAT THE LAST: mislykket tur setter fortsatt (lavere) mål. BEAT THE BEST: round-max resettes hver runde og synker aldri. Fasit fra spec §2 (rev. 2026-07-16).
      </div>
    </div>
  </div>
);

// keyframes
if (typeof document !== 'undefined' && !document.getElementById('oneup-kf')) {
  const st = document.createElement('style');
  st.id = 'oneup-kf';
  st.textContent = `@keyframes ouCrack { 0%{transform:scale(1.4) rotate(-8deg);opacity:0} 40%{transform:scale(1.1) rotate(6deg);opacity:1} 100%{transform:scale(1) rotate(0);opacity:1} }
    @keyframes ouDangerPulse { 0%,100%{box-shadow:0 0 20px ${RED}55} 50%{box-shadow:0 0 34px ${RED}aa} }
    @media (prefers-reduced-motion: reduce){ [style*="ouCrack"],[style*="ouDangerPulse"]{animation:none!important} }`;
  document.head.appendChild(st);
}

// ════════════════════════════════════════════════════════════════
// SCREEN SHELL — lightweight dark arcade wrapper (scanlines + vignette)
// for the non-cockpit screens (home / setup / post-game).
// ════════════════════════════════════════════════════════════════
const OUScreen = ({ children }) => (
  <div style={{width:OU_W, height:OU_H, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', position:'relative', overflow:'hidden', display:'flex', flexDirection:'column'}}>
    <div style={{position:'absolute', inset:0, backgroundImage:ouScan, pointerEvents:'none', zIndex:5}}></div>
    <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
    {children}
  </div>
);

// ── HOME — 3×3 mode grid, 1UP lit (NEW), Golf + WILDCARD dimmed ───
const OU_TILES = [
  { name:'X01', emoji:'🎯' }, { name:'CRICKET', emoji:'🦗' }, { name:'SHANGHAI', emoji:'🏙️' },
  { name:'GOTCHA', emoji:'💀' }, { name:'1UP', emoji:'🕹️', hero:true }, { name:'HALVE IT', emoji:'✂️' },
  { name:'ATC', emoji:'🕐' }, { name:'GOLF', emoji:'⛳', soon:true }, { name:'WILDCARD', emoji:'🃏', soon:true },
];
const OUHome = () => (
  <OUScreen>
    <div style={{padding:'24px 24px 12px', textAlign:'center', position:'relative', zIndex:6}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:26, color:MAGENTA, letterSpacing:3, textShadow:`0 0 12px ${MAGENTA}, 4px 4px 0 ${CYAN}55`}}>DOSSEDART</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.5)', letterSpacing:4, marginTop:8}}>SELECT GAME MODE</div>
    </div>
    <div style={{flex:1, padding:'10px 24px 26px', display:'grid', gridTemplateColumns:'repeat(3,1fr)', gridTemplateRows:'repeat(3,1fr)', gap:16, position:'relative', zIndex:6}}>
      {OU_TILES.map(t=>{
        const c = t.hero ? LIME : CYAN;
        return (
          <div key={t.name} style={{position:'relative', border:`3px solid ${t.soon?'rgba(255,255,255,0.14)':c}`,
            background: t.hero?`linear-gradient(180deg, ${LIME}26, ${LIME}08)`:'rgba(255,255,255,0.03)',
            boxShadow: t.soon?'none':`0 0 18px ${c}55`, opacity: t.soon?0.5:1,
            display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:10}}>
            <div style={{fontSize:38, filter:t.soon?'grayscale(1)':'none'}}>{t.emoji}</div>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color: t.soon?'rgba(255,255,255,0.5)':'#fff', letterSpacing:1, textShadow: t.soon?'none':`0 0 8px ${c}88`, textAlign:'center'}}>{t.name}</div>
            {t.hero && <div style={{position:'absolute', top:-9, right:10, padding:'2px 7px', background:LIME, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:8, letterSpacing:1, boxShadow:`0 0 8px ${LIME}`}}>NEW</div>}
            {t.soon && <div style={{position:'absolute', bottom:9, fontFamily:'"Press Start 2P", monospace', fontSize:8, color:'rgba(255,255,255,0.4)', letterSpacing:1}}>SOON</div>}
          </div>
        );
      })}
    </div>
  </OUScreen>
);

// ── SETUP — reused player list + 1UP option chips/toggle ─────────
const OUChip = ({ label, sub, on, accent=LIME }) => (
  <div style={{flex:1, minWidth:0, padding:'12px 10px', textAlign:'center', border:`2px solid ${on?accent:'rgba(255,255,255,0.16)'}`,
    background:on?`${accent}1e`:'transparent', boxShadow:on?`0 0 14px ${accent}55`:'none'}}>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:on?'#fff':'rgba(255,255,255,0.6)', letterSpacing:1, textShadow:on?`0 0 6px ${accent}`:'none'}}>{label}</div>
    {sub && <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:on?accent:'rgba(255,255,255,0.4)', letterSpacing:1, marginTop:5}}>{sub}</div>}
  </div>
);
const OUOptionBlock = ({ label, children }) => (
  <div style={{marginTop:18}}>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:LIME, letterSpacing:2, marginBottom:10, textShadow:`0 0 6px ${LIME}88`}}>{label}</div>
    <div style={{display:'flex', gap:10}}>{children}</div>
  </div>
);
const OU_SETUP_PLAYERS = [['Jonas','JON',CYAN],['Kari','KAR',MAGENTA],['Per','PER',GREEN],['Mia','MIA',YELLOW]];
const OUSetup = () => (
  <OUScreen>
    <div style={{padding:'16px 22px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:14, position:'relative', zIndex:6}}>
      <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:2}}>◀ BACK</div>
      <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:13, color:LIME, letterSpacing:2, textShadow:`0 0 8px ${LIME}88`}}>🕹️ 1UP · SETUP</div>
      <div style={{width:40}}></div>
    </div>
    <div style={{flex:1, padding:'20px 24px', overflow:'hidden', position:'relative', zIndex:6, display:'flex', flexDirection:'column'}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:'rgba(255,255,255,0.5)', letterSpacing:2, marginBottom:10}}>PLAYERS · 4</div>
      <div style={{display:'flex', flexDirection:'column', gap:8}}>
        {OU_SETUP_PLAYERS.map(([n,h,c])=>(
          <div key={h} style={{display:'flex', alignItems:'center', gap:12, padding:'10px 12px', border:`2px solid ${c}66`, background:`${c}0d`}}>
            <div style={{width:36, height:36, background:BG, border:`2px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:10, color:c}}>{h}</div>
            <div style={{flex:1, fontFamily:'"Press Start 2P", monospace', fontSize:12, color:'#fff', letterSpacing:1}}>{n.toUpperCase()}</div>
            <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.35)'}}>✕</div>
          </div>
        ))}
      </div>
      <OUOptionBlock label="LIVES">
        <OUChip label="1" sub="SUDDEN DEATH" on={false}/>
        <OUChip label="3" sub="DEFAULT" on={true}/>
        <OUChip label="5" sub="LONG GAME" on={false}/>
      </OUOptionBlock>
      <OUOptionBlock label="VARIANT">
        <OUChip label="BEAT THE LAST" sub="last total · continuous" on={true}/>
        <OUChip label="BEAT THE BEST" sub="round max · resets" on={false}/>
      </OUOptionBlock>
      <div style={{marginTop:18, display:'flex', alignItems:'center', gap:12, padding:'12px 14px', border:'2px solid rgba(255,255,255,0.16)'}}>
        <div style={{flex:1}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#fff', letterSpacing:1}}>RANDOM ORDER</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.45)', letterSpacing:1, marginTop:4}}>shuffle rotation each round</div>
        </div>
        <div style={{width:52, height:28, borderRadius:14, background:'rgba(255,255,255,0.1)', border:'2px solid rgba(255,255,255,0.2)', position:'relative'}}>
          <div style={{position:'absolute', top:2, left:2, width:20, height:20, borderRadius:'50%', background:'rgba(255,255,255,0.5)'}}></div>
        </div>
      </div>
      <div style={{marginTop:'auto', padding:'16px', background:`linear-gradient(90deg, ${LIME}, ${GREEN})`, color:BG, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:14, letterSpacing:2, boxShadow:`0 0 22px ${LIME}88`}}>▶ START GAME</div>
    </div>
  </OUScreen>
);

// ── POST-GAME — placements (elimination order) + stat rows ───────
const OU_PLACES = [
  { place:'1ST', name:'JONAS', handle:'JON', accent:CYAN, note:'LAST ALIVE · 2 ♥', metal:YELLOW },
  { place:'2ND', name:'KARI', handle:'KAR', accent:MAGENTA, note:'OUT · ROUND 8', metal:'#C9D2DA' },
  { place:'3RD', name:'PER', handle:'PER', accent:GREEN, note:'OUT · ROUND 6', metal:'#D08A4A' },
  { place:'4TH', name:'MIA', handle:'MIA', accent:YELLOW, note:'OUT · ROUND 5', metal:'rgba(255,255,255,0.3)' },
];
const OU_STATS = [
  ['HIGHEST TURN','140','JONAS'], ['TARGETS SET','9','JONAS'], ['LIVES LOST','7','total'],
  ['TURNS SURVIVED','24','JONAS'], ['SAVED ON LAST DART','3','KARI'],
];
const OUPostGame = () => (
  <OUScreen>
    <div style={{padding:'16px 22px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, textAlign:'center', position:'relative', zIndex:6}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:YELLOW, letterSpacing:2, textShadow:`0 0 8px ${YELLOW}88`}}>🕹️ 1UP · RESULTS</div>
    </div>
    <div style={{flex:1, padding:'18px 24px 22px', overflow:'hidden', position:'relative', zIndex:6, display:'flex', flexDirection:'column'}}>
      <div style={{textAlign:'center', marginBottom:8}}>
        <div style={{fontSize:24, letterSpacing:6, color:YELLOW}}>★ ★ ★</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:28, color:YELLOW, letterSpacing:2, textShadow:`0 0 20px ${YELLOW}, 4px 4px 0 ${MAGENTA}`, marginTop:8}}>JONAS WINS</div>
      </div>
      <div style={{display:'flex', flexDirection:'column', gap:8}}>
        {OU_PLACES.map(p=>(
          <div key={p.handle} style={{display:'flex', alignItems:'center', gap:12, padding:'11px 13px', border:`2px solid ${p.metal}`, background:`${p.accent}0d`}}>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:p.metal, width:38, textShadow:`0 0 8px ${p.metal}88`}}>{p.place}</div>
            <div style={{width:34, height:34, background:BG, border:`2px solid ${p.accent}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:10, color:p.accent}}>{p.handle}</div>
            <div style={{flex:1, fontFamily:'"Press Start 2P", monospace', fontSize:12, color:'#fff', letterSpacing:1}}>{p.name}</div>
            <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.5)', letterSpacing:1}}>{p.note}</div>
          </div>
        ))}
      </div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:LIME, letterSpacing:2, margin:'22px 0 6px', textShadow:`0 0 6px ${LIME}88`}}>MATCH STATS</div>
      <div style={{display:'flex', flexDirection:'column'}}>
        {OU_STATS.map(([label,val,who])=>(
          <div key={label} style={{display:'flex', alignItems:'center', gap:12, padding:'11px 4px', borderBottom:'1px solid rgba(255,255,255,0.08)'}}>
            <div style={{flex:1, fontFamily:'"VT323", monospace', fontSize:19, color:'rgba(255,255,255,0.7)', letterSpacing:1}}>{label}</div>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:15, color:'#fff'}}>{val}</div>
            <div style={{width:82, textAlign:'right', fontFamily:'"VT323", monospace', fontSize:15, color: who==='total'?'rgba(255,255,255,0.4)':YELLOW, letterSpacing:1}}>{who}</div>
          </div>
        ))}
      </div>
      <div style={{marginTop:'auto', display:'flex', gap:10}}>
        <div style={{flex:1, padding:'14px', border:`2px solid ${CYAN}`, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, letterSpacing:1}}>↶ UNDO</div>
        <div style={{flex:2, padding:'14px', background:ORANGE, color:BG, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:11, letterSpacing:1, boxShadow:`0 0 16px ${ORANGE}88`}}>▶ REMATCH</div>
      </div>
    </div>
  </OUScreen>
);

// ── PALETTE EXTENSION — new accent token proposal (fasit card) ───
const OU_TAKEN = [
  ['magenta','#FF00AA','chrome / brand'], ['cyan','#00E5FF','active / focus'], ['yellow','#FFD200','hero / highlight'],
  ['green','#3DFF8E','positive'], ['red','#FF3050','negative / danger'], ['purple','#7B3FFF','2nd accent (WILDCARD + Halve It)'], ['orange','#FF7A00','warm / start CTA'],
];
const OUPaletteCard = () => (
  <div style={{boxSizing:'border-box', width:680, height:1300, background:'#fffdf6', border:'1.5px solid rgba(0,0,0,0.14)', padding:'30px 34px', fontFamily:'"Inter", system-ui, sans-serif', display:'flex', flexDirection:'column', gap:16, overflow:'hidden'}}>
    <div>
      <div style={{display:'flex', alignItems:'center', gap:10, marginBottom:6}}>
        <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600}}>1UP · palett-utvidelse</div>
        <div style={{padding:'2px 8px', background:'#e9dcff', border:'1px solid #b79aff', fontFamily:'"JetBrains Mono", monospace', fontSize:10, fontWeight:700, color:'#5a2ea6', letterSpacing:1}}>PROPOSAL</div>
      </div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:26, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.08}}>Ett nytt aksent-token for 1UP</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, color:'#5a544a', lineHeight:1.5, marginTop:8}}>De 7 DOSSEDART-aksentene er alle i bruk (WILDCARD deler allerede lilla med Halve It). 1UP trenger en egen merkevarefarge. Implementasjon legger tokenet i <b>DossedartTokens</b>.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12, fontWeight:800, color:'#2a251f', marginBottom:8, textTransform:'uppercase', letterSpacing:0.5}}>Opptatt · 7 aksenter</div>
      <div style={{display:'grid', gridTemplateColumns:'repeat(2,1fr)', gap:8}}>
        {OU_TAKEN.map(([n,hex,use])=>(
          <div key={n} style={{display:'flex', alignItems:'center', gap:9, padding:'7px 9px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
            <div style={{width:20, height:20, background:hex, border:'1px solid rgba(0,0,0,0.2)', flexShrink:0}}></div>
            <div style={{minWidth:0}}>
              <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, fontWeight:700, color:'#2a251f'}}>{n} <span style={{color:'#8a8378', fontWeight:400}}>{hex}</span></div>
              <div style={{fontFamily:'"Inter", sans-serif', fontSize:11, color:'#5a544a', overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap'}}>{use}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
    <div style={{padding:'18px 20px', background:'linear-gradient(180deg,#f7ffe6,#eefcd6)', border:`2px solid ${LIME}`, boxShadow:`0 0 0 1px ${LIME}55`}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12, fontWeight:800, color:'#3f5406', textTransform:'uppercase', letterSpacing:1, marginBottom:12}}>Forslag · nytt token</div>
      <div style={{display:'flex', alignItems:'center', gap:16}}>
        <div style={{width:88, height:88, background:LIME, border:'2px solid #2a251f', boxShadow:`0 4px 14px ${LIME}aa`, flexShrink:0}}></div>
        <div>
          <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:22, fontWeight:700, color:'#2a251f'}}>lime</div>
          <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:18, color:'#3f5406'}}>#C6FF3C</div>
          <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, color:'#4a5a2a', marginTop:4}}>Rolle: <b>1UP / extra-life aksent</b> — modus-merkevare + free-throw «SET THE TARGET»-highlight.</div>
        </div>
      </div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#4a5a2a', lineHeight:1.55, marginTop:14}}>
        <b>Hvorfor:</b> fyller det eneste ledige hue-gapet i neon-paletten (~60–100°, mellom yellow #FFD200 og mint-green #3DFF8E). Leser umiddelbart som retro «1UP / extra life», og kolliderer ikke med noen av de 7 rollene. Brukes aldri som spillerfarge — spillerkort beholder <code>player_colors</code>.
      </div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Brukt i disse artboardene</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Home-tile (1UP «NEW»-glød), Setup (seksjonslabels + valgt chip + START-CTA), Cockpit (variant-chip + free-throw-headline), dette palett-kortet. Rød/grønn beholder rollene fare/SAFE; lime er kun modus-identitet.</div>
    </div>
    <div style={{marginTop:'auto', padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, lineHeight:1.55, color:'#5a544a'}}><b>PROPOSAL</b> — parkert til godkjenning. Implementasjon legger <code>lime = Color(0xFFC6FF3C)</code> i <code>DossedartTokens</code>; ingen andre tokens endres.</div>
    </div>
  </div>
);

// ── Canvas ───────────────────────────────────────────────────────
const OneUpCockpit = () => (
  <React.Fragment>
    <DCSection id="ou-home" title="Home — 3×3 mode grid"
      subtitle="1UP-tile i tent/shipped-variant (lime «NEW»-glød). Golf + WILDCARD vist som dimmede coming-soon-tiles. Tile-chrome er gjenbruk; kun grid 2→3 kolonner er nytt.">
      <DCArtboard id="ou-home-1" label="Home · 1UP lit" width={OU_W} height={OU_H}><OUHome/></DCArtboard>
    </DCSection>

    <DCSection id="ou-setup" title="Setup — 1UP-alternativer"
      subtitle="Gjenbruker PlayerSetupScreen + tre nye chip/toggle-kontroller: LIVES (1/3/5, default 3), VARIANT (BEAT THE LAST / BEAT THE BEST), RANDOM ORDER (default av).">
      <DCArtboard id="ou-setup-1" label="Setup · options" width={OU_W} height={OU_H}><OUSetup/></DCArtboard>
    </DCSection>

    <DCSection id="ou-cockpit" title="1UP cockpit — liv, mål og BEAT"
      subtitle="Samme cockpit-skjelett som X01/Gotcha (Frame, TopBar, låst CRT-tavle, MISS-hjørner, ActionBar) er urørt. Karusellen beholder mønsteret. Nytt: BEAT <mål> + NEED n MORE (tie = success — NEED = target − turnTotal, SAFE ved >=), LIFE PIPS, og states SAFE / CAN'T-BEAT / free throw / life lost / last life / elimination / winner. Variant-chip viser BEAT THE LAST / BEAT THE BEST.">
      <DCArtboard id="ou-1" label="1 · Free throw (SET THE TARGET)" width={OU_W} height={OU_H}><OUCockpit s={OU_STATES.open}/></DCArtboard>
      <DCArtboard id="ou-1b" label="1b · Free throw · BEAT THE BEST" width={OU_W} height={OU_H}><OUCockpit s={OU_STATES.bestFree}/></DCArtboard>
      <DCArtboard id="ou-2" label="2 · Default (BEAT + NEED)" width={OU_W} height={OU_H}><OUCockpit s={OU_STATES.default}/></DCArtboard>
      <DCArtboard id="ou-3" label="3 · SAFE (target matched/beaten)" width={OU_W} height={OU_H}><OUCockpit s={OU_STATES.safe}/></DCArtboard>
      <DCArtboard id="ou-4" label="4 · CAN'T BEAT (life at risk)" width={OU_W} height={OU_H}><OUCockpit s={OU_STATES.cant}/></DCArtboard>
      <DCArtboard id="ou-6" label="6 · Last life (danger styling)" width={OU_W} height={OU_H}><OUCockpit s={OU_STATES.lastlife}/></DCArtboard>
      <DCArtboard id="ou-5" label="5 · Life lost ← moment" width={OU_W} height={OU_H}><OUCockpit s={OU_STATES.lifelost}/></DCArtboard>
      <DCArtboard id="ou-7" label="7 · Elimination" width={OU_W} height={OU_H}><OUCockpit s={OU_STATES.eliminated}/></DCArtboard>
      <DCArtboard id="ou-8" label="8 · Winner (1UP!)" width={OU_W} height={OU_H}><OUCockpit s={OU_STATES.winner}/></DCArtboard>
    </DCSection>

    <DCSection id="ou-postgame" title="Post-game — placements + stats"
      subtitle="Gjenbruker post_game_screen. Placements etter eliminasjonsrekkefølge (vinner først). Mode-spesifikke stat-rader: highest turn, targets set, lives lost, turns survived, saved on last dart.">
      <DCArtboard id="ou-post-1" label="Post-game · results" width={OU_W} height={OU_H}><OUPostGame/></DCArtboard>
    </DCSection>

    <DCSection id="ou-spec" title="1UP — fasit + palett"
      subtitle="Skjelettet er gjenbruk. Ny innsats: kort-innhold, life pips, states, to varianter (rev. 2026-07-16), og et foreslått palett-token.">
      <DCArtboard id="ou-spec-card" label="Spec · 1UP" width={680} height={1300}><OUSpecCard/></DCArtboard>
      <DCArtboard id="ou-palette-card" label="Palette · PROPOSAL" width={680} height={1300}><OUPaletteCard/></DCArtboard>
    </DCSection>
  </React.Fragment>
);
window.OneUpCockpit = OneUpCockpit;
