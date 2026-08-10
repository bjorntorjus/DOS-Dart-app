// DOSSEDART — Post-game round · fasit spec card (paper)
const SP={ink:'#2a251f',mut:'#5a544a',line:'rgba(0,0,0,0.09)',paper:'#fffdf6',tint:'#f4f0e8',accent:'#c96442'};
const SPI='"Inter", system-ui, sans-serif', SPM='"JetBrains Mono", monospace';
const Blk=({title,children,tint})=>(
  <div style={{padding:tint?'11px 13px':0,background:tint?SP.tint:'transparent',border:tint?`1px solid ${SP.line}`:'none'}}>
    <div style={{fontFamily:SPI,fontSize:12,fontWeight:800,color:SP.ink,marginBottom:6,textTransform:'uppercase',letterSpacing:0.6}}>{title}</div>
    <div style={{fontFamily:SPI,fontSize:11.5,lineHeight:1.5,color:SP.mut}}>{children}</div>
  </div>
);
const Row=({k,v})=>(
  <div style={{display:'flex',gap:10,padding:'5px 0',borderBottom:`1px solid ${SP.line}`}}>
    <div style={{flex:1,fontFamily:SPI,fontSize:11.5,fontWeight:600,color:SP.ink}}>{k}</div>
    <div style={{fontFamily:SPM,fontSize:11,color:SP.mut,textAlign:'right',whiteSpace:'nowrap'}}>{v}</div>
  </div>
);
const Card=({kick,title,children})=>(
  <div style={{boxSizing:'border-box',width:680,height:1180,background:SP.paper,border:'1.5px solid rgba(0,0,0,0.14)',padding:'28px 30px',display:'flex',flexDirection:'column',gap:13,overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:SPM,fontSize:10,letterSpacing:2,color:SP.accent,textTransform:'uppercase',fontWeight:600,marginBottom:5}}>{kick}</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif',fontSize:25,fontWeight:900,letterSpacing:-0.5,color:SP.ink,lineHeight:1.05}}>{title}</div>
    </div>
    {children}
  </div>
);

const SpecZones=()=>(
  <Card kick="Fasit · 1 of 2 · zones + budget" title="Post-game · zone budget @ 820 × 1180">
    <Blk title="Vertical budget (fixed)" >
      <Row k="TopBar (DossedartTopBar, verbatim)" v="52 px · pinned"/>
      <Row k="Winner spotlight" v="196 px · pinned"/>
      <Row k="Scroll region" v="798 px · flex"/>
      <Row k="Action bar" v="134 px · pinned"/>
      <div style={{marginTop:7,fontSize:11.5}}>Only the middle region scrolls. The action bar can never be pushed off — it is a sibling of the scroll view, not its last item (today the chart is a list item and the buttons float above it).</div>
    </Blk>
    <Blk title="Winner spotlight — 196 px" tint>
      Horizontal, not stacked: <b>104 px avatar</b> (yellow 3 px border, 18 px glow, 👑 overhanging the top edge) · <b>★ WINNER ★</b> PS-11 yellow, letterspacing 4 · <b>name</b> PS 26/21/17/13 by length (≤8/≤12/≤16/longer) · headline value repeated VT-19 under it · two right-hand plates: the mode headline (yellow) and <b>ELO</b> (green, or a dimmed “—” when the mode does not rate). Radial yellow wash at 24% 40%, 12% opacity. No trophy emoji, no gradient card.
    </Blk>
    <Blk title="Standings — every player, one size">
      Card: surface <span style={{fontFamily:SPM}}>#1A0030</span>, 2 px border in the player accent (5-accent cycle, rule 7), 1st place borders yellow + 14 px glow. Padding 11/12/12. Header row 40 px: rank plate 38 px (gold / silver <span style={{fontFamily:SPM}}>#C0C0C0</span> / bronze, else dim) · 40 px photo avatar · name PS 14/12/10/9 by length + <span style={{fontFamily:SPM}}>YOU</span> tag · headline label VT-15 · <b>headline value PS-20 in the player accent</b> · Elo column fixed 86 px. All cards identical height for a given mode — no expanded “you” row, no top-3 exception.
    </Blk>
    <Blk title="Stat grid — the wall-of-text fix" tint>
      <b>3 fixed columns</b>, cell 34 px, gap 6, label VT-15 left / value PS-10 right, 1 px magenta hairline. Rows = <span style={{fontFamily:SPM}}>ceil(fields / 3)</span>.<br/>
      <b>Ordering rule (fasit):</b> the mode’s headline never enters the grid — it lives in the row header. Remaining fields fill left→right, top→bottom in the order the mode declares them in §4 of the brief; that declared order is the spec, so a new wave-2 counter is appended at the end of its mode’s list and lands in the next free slot.<br/>
      <b>Trailing slots:</b> a partial last row is padded with empty dim tracks (border 10% opacity, no text) so every mode is a clean rectangle.<br/>
      <b>Conditional fields at zero</b> (Elims, Stolen, Rounds won, Shanghai!): <b>rendered in place, dimmed to 0.34, value “—”</b>. Never removed — the grid keeps identical geometry between two games of the same mode (grammar rule 2).
    </Blk>
    <Blk title="Card height per mode (derived, no tuning)">
      <Row k="Header row (rank · avatar · name · headline · Elo)" v="40 px"/>
      <Row k="Splitscore · Shanghai (3) · Cricket · ATC · Killer (4)" v="1 grid row · card 106 px"/>
      <Row k="Golf (6) · X01 · Gotcha · Wildcard (7)" v="2 grid rows · card 146 px"/>
      <Row k="1UP (8)" v="3 grid rows · card 186 px"/>
      <div style={{marginTop:7}}>Measured scroll content: Splitscore × 3 = <b>772 px</b> (fits, no scroll) · X01 × 3 = <b>904 px</b> · Golf × 3 with scorecard = <b>1063 px</b> · X01 × 6 = <b>1390 px</b>. Region is 798 px, so the everyday case scrolls 106 px and the worst case 592 px.</div>
    </Blk>
    <div style={{marginTop:'auto',padding:'11px 13px',background:'#dcefe1',border:'1px solid rgba(42,138,82,0.3)',fontFamily:SPI,fontSize:11.5,lineHeight:1.5,color:'#2a4a36'}}>
      <b>One framework, ten modes.</b> Implementation fills the remaining seven modes by declaring a headline + an ordered field list. No further design round is needed for a mode that fits 3–8 fields; a mode that wants a 9th field needs one.
    </div>
  </Card>
);

const SpecStates=()=>(
  <Card kick="Fasit · 2 of 2 · states, colour, actions" title="Post-game · states + roles">
    <Blk title="Colour roles (tokens only)">
      <Row k="1st place · winner · crown" v="YELLOW #FFD200"/>
      <Row k="2nd place plate" v="SILVER #C0C0C0"/>
      <Row k="3rd place plate" v="ORANGE (bronze)"/>
      <Row k="Player identity (avatar, border, headline)" v="5-accent cycle"/>
      <Row k="Elo up / down / none" v="GREEN / RED / dim —"/>
      <Row k="Match summary values" v="LIME #C6FF3C"/>
      <Row k="Chrome rules · hairlines" v="MAGENTA"/>
      <Row k="FINISH GAME (primary)" v="LIME fill, BG text"/>
      <div style={{marginTop:7}}>Lime is reserved for game-level numbers and the one primary action, so the match summary reads as a different class of number than the per-player accents.</div>
    </Blk>
    <Blk title="Match summary — bottom of the scroll" tint>
      3 × 2 grid of label/value cells under the chart: DURATION · ROUNDS · DARTS THROWN · BEST TURN (+ who and which round, as a sub-line) · HIT DISTRIBUTION (<span style={{fontFamily:SPM}}>T · D · B · ✗</span>) · BIGGEST LEAD.<br/>
      <b>Degraded state:</b> when <span style={{fontFamily:SPM}}>throwHistory</span> is suppressed, DURATION renders normally and the other five dim to 0.34 with “—”; BEST TURN carries the sub-line <span style={{fontFamily:SPM}}>NOT RECORDED</span>. The zone keeps its full size — the section label gains “· partly unavailable”. Same rule for BIGGEST LEAD in 1UP and Killer, which have no progression series: dim, “—”, in place.
    </Blk>
    <Blk title="Actions — 134 px, two rows">
      Row 1: <span style={{fontFamily:SPM}}>↶ BACK</span> (magenta) · <span style={{fontFamily:SPM}}>▶ CONTINUE</span> (cyan) · <span style={{fontFamily:SPM}}>▶ DETAILS</span> (purple). Row 2: <span style={{fontFamily:SPM}}>✓ FINISH GAME</span> full width, lime fill.<br/>
      Today’s three stacked rows become two. Conditional buttons (CONTINUE when not eligible, DETAILS on a changed roster) are <b>rendered and dimmed to 0.28</b>, not removed — the primary action never moves.
    </Blk>
    <Blk title="Stress states — resolved" tint>
      <b>6 players:</b> standings scroll; the winner and the action bar stay pinned, so the scroll is the only thing that grows.<br/>
      <b>Long names:</b> the PS size curve bottoms at 9 px in the standings and 13 px in the spotlight (tested at 24 chars); both ellipsis rather than wrap.<br/>
      <b>Tie:</b> shared placement number on both cards + a VT-15 <span style={{fontFamily:SPM}}>TIED</span> tag after the name; the medal plate colour is shared too. Tied 1st = both cards get the yellow border, spotlight shows the first by seat order (implementation’s existing rule).<br/>
      <b>Roster changed:</b> orange notice above the standings · no chart section · DETAILS dimmed · match summary degraded. All four at once, one artboard.<br/>
      <b>Wildcard:</b> the Elo column stays 86 px wide and renders a dimmed “—” for everyone, so the standings’ column geometry is mode-independent.
    </Blk>
    <Blk title="Reused verbatim">
      <span style={{fontFamily:SPM}}>ProgressionChart</span> under a SCORE PER ROUND label, 168 px tall, full inner width · <span style={{fontFamily:SPM}}>GolfScoreGrid</span> under a SCORECARD label, own horizontal scroll, above the chart · <span style={{fontFamily:SPM}}>DossedartCrtFrame</span> / <span style={{fontFamily:SPM}}>DossedartTopBar</span> / <span style={{fontFamily:SPM}}>DossedartPlayerAvatar</span>. Internals untouched. Depth stays in KAMPDETALJER behind DETAILS.
    </Blk>
    <div style={{marginTop:'auto',padding:'11px 13px',background:'#fdeee6',border:`1px solid ${SP.accent}55`,fontFamily:SPI,fontSize:11.5,lineHeight:1.5,color:'#6a3a26'}}>
      <b>PROPOSAL — parked by default.</b> (1) The match duration is mirrored in the TopBar’s right slot, where the cockpit shows the round counter — costs nothing, but it is new. (2) BEST TURN naming the thrower is the only place a game-level number credits a player; drop it to a bare number if that reads as a second leaderboard. Neither is fasit.
    </div>
  </Card>
);

window.PostgameSpec=()=>(
  <DCSection id="pg-fasit" title="5 · Fasit" subtitle="Two spec cards: zones + the stat-grid ordering rule, then colour roles, states and actions. Everything outside these two cards is illustration.">
    <DCArtboard id="pg-spec-1" label="Fasit 1 · zones + stat grid" width={680} height={1180}><SpecZones/></DCArtboard>
    <DCArtboard id="pg-spec-2" label="Fasit 2 · states + roles" width={680} height={1180}><SpecStates/></DCArtboard>
  </DCSection>
);
