const $=id=>document.getElementById(id);
const esc=v=>String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const allNodes=()=>projects.flatMap(p=>p.nodes.map(n=>({...n,project:p})));
const names={working:'Working',waiting:'Needs input',idle:'Idle',done:'Done'};
const state={tab:'usage',route:{type:'usage'},stack:[],query:'',project:'all',status:'all',collapsed:new Set(['docs-main','release-main']),showDone:true,scenario:'sample',step:0,scrolls:new Map()};
const arrow='<svg class="chevron" aria-hidden="true" viewBox="0 0 16 16"><path d="m6 3 5 5-5 5"/></svg>';
let toastTimer;
function toast(message){$('toast').textContent=message;$('toast').hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>$('toast').hidden=true,3400)}
function status(n){return `<span class="status ${n.state}"><span class="state-mark"></span>${names[n.state]}</span>`}
function providerIcon(a){return `<svg class="provider-icon" aria-hidden="true" viewBox="0 0 20 20">${a.provider==='Claude'?'<path d="M10 2v16M2 10h16M4 4l12 12M4 16 16 4"/>':'<path d="m7 5-5 5 5 5m6-10 5 5-5 5M11 3l-2 14"/>'}</svg>`}
function usageWindows(a){return `<div class="usage-grid">${a.windows.map(w=>`<div class="window"><div class="window-label"><span>${w.label}</span><strong>${w.used}%</strong></div><div class="usage-track" role="meter" aria-label="${a.provider} ${a.alias} ${w.label} percent used" aria-valuenow="${w.used}" aria-valuemin="0" aria-valuemax="100"><div class="usage-fill ${w.used>=85?'risk':''}" style="width:${w.used}%"></div></div><p class="reset">${w.reset}</p></div>`).join('')}</div>`}
function routeKey(route=state.route){return `${route.type}:${route.id??''}`}
function saveScroll(){state.scrolls.set(routeKey(),$('content').scrollTop)}
function focusHeading(){$('screen-title').setAttribute('tabindex','-1');$('screen-title').focus({preventScroll:true})}
function push(route){saveScroll();state.stack.push(state.route);state.route=route;render();$('content').scrollTop=0;focusHeading()}
function back(){if(!state.stack.length)return;state.route=state.stack.pop();render();$('content').scrollTop=state.scrolls.get(routeKey())??0;focusHeading()}
function switchTab(tab){saveScroll();state.tab=tab;state.route={type:tab};state.stack=[];render();$('content').scrollTop=state.scrolls.get(routeKey())??0}
function bindNavigation(){document.querySelectorAll('[data-account]').forEach(b=>b.onclick=()=>push({type:'account',id:b.dataset.account}));document.querySelectorAll('[data-agent]').forEach(b=>b.onclick=()=>push({type:'agent',id:b.dataset.agent}));document.querySelectorAll('[data-settings]').forEach(b=>b.onclick=()=>push({type:'settings'}))}
function renderUsage(){
  const waiting=state.scenario==='empty'?0:allNodes().filter(n=>n.state==='waiting').length;
  $('content').innerHTML=`<div class="overview-line"><span>${accounts.length} accounts · percent used</span><button id="needs-input">${waiting?`${waiting} agent needs input`:'View agents'} →</button></div>${accounts.map(a=>`<article class="account-card"><div class="account-top">${providerIcon(a)}<button class="account-open" data-account="${a.id}" aria-label="View ${a.provider} ${a.alias} account"><h2>${a.provider} / ${a.alias} <span class="plan">${a.tier}</span></h2>${arrow}</button></div>${usageWindows(a)}${a.note?`<p class="reset">${a.note}</p>`:''}<p class="freshness">${a.stale?'<span class="stale-label">Last known</span> · ':''}${a.source} · ${a.age}</p></article>`).join('')}<div class="sources-line"><button data-settings>Connections & settings →</button><span>Local only</span></div>`;
  $('needs-input').onclick=()=>{state.status=waiting?'waiting':'all';switchTab('agents')};bindNavigation();
}
function matchingProjects(){
  if(state.scenario==='empty')return [];
  return projects.filter(p=>state.project==='all'||state.project===p.id).map(p=>{
    const direct=p.nodes.filter(n=>(state.showDone||n.state!=='done')&&(state.status==='all'||state.status===n.state)&&(!state.query||`${n.name} ${n.role} ${n.source} ${p.name}`.toLowerCase().includes(state.query)));
    const ids=new Set(direct.map(n=>n.id));
    direct.forEach(n=>{let parent=n.parent??n.memberOf;while(parent){ids.add(parent);const item=p.nodes.find(x=>x.id===parent);parent=item?.parent??item?.memberOf}});
    return {...p,nodes:p.nodes.filter(n=>ids.has(n.id)),matched:direct};
  }).filter(p=>p.nodes.length);
}
function renderTree(){
  const groups=matchingProjects(),matched=groups.flatMap(p=>p.matched);
  const count=s=>matched.filter(n=>n.state===s).length;
  $('agent-stats').innerHTML=`<div class="stat"><strong>${count('working')}</strong><span>${state.scenario==='offline'?'Last known working':'Working'}</span></div><div class="stat"><strong class="${count('waiting')?'warning':''}">${count('waiting')}</strong><span>Needs input</span></div><div class="stat"><strong>${groups.flatMap(p=>p.nodes).filter(n=>!n.parent&&!n.memberOf).length}</strong><span>Root sessions</span></div>`;
  $('list-info').textContent=`${matched.length} matching agents · ${groups.length} projects${state.query||state.status!=='all'?' · ancestors retained':''}`;
  if(!groups.length){$('session-tree').innerHTML=`<div class="empty"><h2>${state.scenario==='empty'?'No sessions observed':'No matching agents'}</h2><p>${state.scenario==='empty'?'Local session events will appear here after you enable an integration. Relay does not start agents.':'Try a different project, state, or search term.'}</p><button class="button" id="restore">${state.scenario==='empty'?'Restore sample':'Clear filters'}</button></div>`;$('restore').onclick=()=>{state.scenario='sample';resetFilters();render()};return}
  const nodeHTML=(n,p,depth)=>{
    const children=p.nodes.filter(x=>x.parent===n.id||x.memberOf===n.id),collapsed=state.collapsed.has(n.id)&&!state.query&&state.status==='all';
    return `<div class="agent-row ${depth&&!n.unknownParent?'child':''}" style="--depth:${depth}">${children.length?`<button class="collapse" data-collapse="${n.id}" aria-label="${collapsed?'Expand':'Collapse'} ${esc(n.name)}" aria-expanded="${!collapsed}"><svg aria-hidden="true" viewBox="0 0 12 12"><path d="m3 4 3 3 3-3"/></svg></button>`:'<span class="node-leaf" aria-hidden="true"></span>'}<button class="node-open" data-agent="${n.id}"><span class="node-copy"><span class="node-name">${esc(n.name)}</span><span class="node-meta">${n.unknownParent?'Parent unknown · ':''}${esc(n.source)} · ${n.elapsed}</span></span>${status(n)}</button></div>${collapsed?'':children.map(c=>nodeHTML(c,p,depth+1)).join('')}`;
  };
  $('session-tree').innerHTML=groups.map(p=>`<section class="project-group" aria-label="${p.name} sessions"><div class="project-title"><h2>${p.name}</h2><span>${p.matched.length} agents</span></div>${p.nodes.filter(n=>!n.parent&&!n.memberOf).map(n=>nodeHTML(n,p,0)).join('')}</section>`).join('');
  document.querySelectorAll('[data-collapse]').forEach(b=>b.onclick=()=>{const id=b.dataset.collapse;state.collapsed.has(id)?state.collapsed.delete(id):state.collapsed.add(id);renderTree()});bindNavigation();
}
function renderAgents(){
  $('content').innerHTML=`${state.scenario==='offline'?'<p class="notice">Collector offline. These states are last known, not live.</p>':''}<div class="stats" id="agent-stats"></div><label class="search"><svg aria-hidden="true" viewBox="0 0 20 20"><circle cx="8" cy="8" r="5"/><path d="m12 12 5 5"/></svg><input id="search" type="search" aria-label="Find an agent or source" placeholder="Find an agent or source" value="${esc(state.query)}"></label><div class="filters"><select id="project-filter" aria-label="Filter by project"><option value="all">All projects</option>${projects.map(p=>`<option value="${p.id}">${p.name}</option>`).join('')}</select><select id="status-filter" aria-label="Filter by state"><option value="all">All states</option><option value="working">Working</option><option value="waiting">Needs input</option><option value="idle">Idle</option><option value="done">Done</option></select></div><p class="list-info" id="list-info"></p><div id="session-tree"></div><p class="quiet-note">Lines mean reported parent → child links. Session membership alone does not establish a parent.</p>`;
  $('project-filter').value=state.project;$('status-filter').value=state.status;
  $('search').oninput=e=>{state.query=e.target.value.trim().toLowerCase();renderTree()};
  $('project-filter').onchange=e=>{state.project=e.target.value;renderTree()};$('status-filter').onchange=e=>{state.status=e.target.value;renderTree()};renderTree();
}
function fact(label,value){return `<div class="fact"><dt>${label}</dt><dd>${value}</dd></div>`}
function renderAgent(){
  const n=allNodes().find(n=>n.id===state.route.id),parent=allNodes().find(x=>x.id===n.parent),a=accounts.find(a=>a.id===n.account),children=allNodes().filter(x=>x.parent===n.id||x.memberOf===n.id);
  $('content').innerHTML=`${state.scenario==='offline'?'<p class="notice">Collector offline. Details are last known.</p>':''}<div class="detail-status">${status(n)}<span>${n.elapsed} elapsed</span></div><p class="task-text">${esc(n.task)}</p><dl class="fact-list">${fact('Source',esc(n.source))}${fact('Project',`${esc(n.project.name)}<small>${esc(n.project.branch)}</small>`)}${fact('Parent',parent?`<button data-agent="${parent.id}">${esc(parent.name)}</button><small>Reported link · sample</small>`:n.unknownParent?'Unknown<small>Session membership only</small>':'Root session')}${fact('Account',a?`<button data-account="${a.id}">${a.provider} / ${a.alias}</button><small>Sample association, not live-verified</small>`:'Unknown<small>Model does not identify a billing account</small>')}</dl>${children.length?`<section class="subagents"><h2 class="section-title">${children.length} linked agents</h2>${children.map(c=>`<button class="member-button" data-agent="${c.id}"><span>${esc(c.name)}</span>${status(c)}</button>`).join('')}</section>`:''}<section><h2 class="section-title">Latest events · simulated</h2>${n.events.map(e=>`<div class="event"><time>${e[0]}</time><p>${esc(e[1])}</p></div>`).join('')}</section>`;bindNavigation();
}
function renderAccount(){
  const a=accounts.find(a=>a.id===state.route.id),linked=state.scenario==='empty'?[]:allNodes().filter(n=>n.account===a.id&&n.state!=='done');
  $('content').innerHTML=`<div class="account-detail">${a.stale?'<p class="notice">Last-known measurement. Claude telemetry may stop updating while its sessions are idle.</p>':''}${usageWindows(a)}${a.note?`<p class="quiet-note">${a.note}. An absent window is not a zero or a promise of unlimited usage.</p>`:''}<dl class="fact-list">${fact('Subscription',a.tier)}${fact('Source',a.source)}${fact('Last observed',a.age)}${fact('Account scope','This account only')}</dl><section><h2 class="section-title">${linked.length} associated open agents · sample</h2>${linked.map(n=>`<button class="member-button" data-agent="${n.id}"><span>${esc(n.name)}</span>${status(n)}</button>`).join('')||'<p class="quiet-note">No associated open agents. Unattributed sessions remain visible in Agents.</p>'}</section><p class="quiet-note">These are account-wide allowances, not per-agent usage. Values and reset labels are frozen sample data.</p></div>`;bindNavigation();
}
function renderSettings(){
  $('content').innerHTML=`<section class="settings-group"><h2>Local connections</h2><details class="connection"><summary>Claude Code</summary><p>Opt-in lifecycle hooks and quota telemetry. Nested parents may be unknown. No subscription tokens or browser cookies are collected.</p></details><details class="connection"><summary>Codex</summary><p>Opt-in trusted hooks for activity. Isolated app-server profiles for usage, subject to provider eligibility. One server is not a global live session bus.</p></details><details class="connection"><summary>OpenCode</summary><p>Read-only metadata snapshots from an explicitly connected V2 service. Model names do not establish account identity.</p></details><details class="connection"><summary>Orca orchestration</summary><p>Read-only CLI snapshots and recorded supervised creator links. Workspace lineage is not agent ancestry. Coverage may be incomplete.</p></details></section><section class="settings-group"><h2>Display</h2><label class="settings-toggle"><span>Show completed agents<small>Keep observed finished work in the session tree.</small></span><input id="show-done" type="checkbox" ${state.showDone?'checked':''}></label></section><section class="settings-group"><label class="form-label" for="scenario">Demo scenario</label><select id="scenario"><option value="sample">Sample activity</option><option value="offline">Collector offline</option><option value="empty">No sessions</option></select></section><p class="quiet-note">Preview only. No connections are configured here. Nothing is persisted, no requests are approved, and no agents are launched. Target: macOS 14+ · free and open-source.</p>`;
  $('scenario').value=state.scenario;$('scenario').onchange=e=>{state.scenario=e.target.value;render();toast('Demo scenario updated. No real sessions were changed.')};$('show-done').onchange=e=>{state.showDone=e.target.checked;updateChrome()};
}
function resetFilters(){state.query='';state.project='all';state.status='all'}
function updateChrome(){
  const nodes=state.scenario==='empty'?[]:allNodes(),working=nodes.filter(n=>n.state==='working').length;
  $('menu-count').textContent=`${working} ${state.scenario==='offline'?'last known':'working'}`;$('menu-usage').textContent=`${Math.max(...accounts.flatMap(a=>a.windows.map(w=>w.used)))}% max`;
  $('agent-badge').textContent=nodes.filter(n=>state.showDone||n.state!=='done').length;
  $('footer-status').innerHTML=`<span class="dot" style="${state.scenario==='offline'?'background:var(--warning)':''}"></span>${state.scenario==='offline'?'Offline · last known':'Sample data · 10:42'}`;
  $('advance').disabled=state.scenario!=='sample';
}
function render(){
  const route=state.route,n=route.type==='agent'?allNodes().find(n=>n.id===route.id):null,a=route.type==='account'?accounts.find(a=>a.id===route.id):null;
  const root=route.type==='usage'||route.type==='agents';$('tabs').hidden=!root;$('back').hidden=!state.stack.length;$('brand-mark').hidden=!root;$('settings').hidden=route.type==='settings';
  $('screen-title').textContent=n?n.name:a?`${a.provider} / ${a.alias}`:route.type==='settings'?'Settings':'Relay';
  $('screen-subtitle').textContent=n?`${n.role} · ${n.source}`:a?`${a.tier} subscription · sample account`:route.type==='settings'?'Connections, display & demo states.':'All your work, one glance.';
  document.querySelectorAll('[data-tab]').forEach(b=>{b.removeAttribute('aria-current');if(b.dataset.tab===state.tab)b.setAttribute('aria-current','page')});
  if(route.type==='usage')renderUsage();else if(route.type==='agents')renderAgents();else if(route.type==='agent')renderAgent();else if(route.type==='account')renderAccount();else renderSettings();updateChrome();
}
function togglePopover(open){const next=open??$('popover').hidden;$('popover').hidden=!next;$('menu-trigger').setAttribute('aria-expanded',String(next));if(!next)$('menu-trigger').focus();else ($('back').hidden?$(state.tab==='usage'?'usage-tab':'agents-tab'):$('back')).focus()}
$('menu-trigger').onclick=()=>togglePopover();$('back').onclick=back;$('settings').onclick=()=>push({type:'settings'});document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>switchTab(b.dataset.tab));
$('advance').onclick=()=>{const ids=['review','shell','provider','orchestrator'],n=projects.flatMap(p=>p.nodes).find(n=>n.id===ids[state.step++%ids.length]);n.state=n.state==='waiting'?'working':n.state==='working'?'done':'working';if(n.id==='review')n.task=n.state==='working'?'Simulated decision received. Continuing the privacy review.':'Privacy review finished in this demo.';n.events.unshift(['10:43',`Demo state changed to ${names[n.state].toLowerCase()}`]);n.events=n.events.slice(0,3);render();toast(`Simulated: ${n.name} is ${names[n.state].toLowerCase()}. No real agent was changed.`)};
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!$('popover').hidden){if(state.stack.length)back();else togglePopover(false)}if(e.key==='Tab'&&!$('popover').hidden){const items=[...$('popover').querySelectorAll('button,input,select,summary')].filter(el=>el.getClientRects().length&&!el.disabled),first=items[0],last=items.at(-1);if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus()}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus()}}});
// Check before click handlers can replace the clicked element during navigation.
document.addEventListener('pointerdown',e=>{if(!$('popover').hidden&&!$('popover').contains(e.target)&&!$('menu-trigger').contains(e.target))togglePopover(false)});
console.assert(new Set(allNodes().map(n=>n.id)).size===allNodes().length,'Unique node IDs');
console.assert(allNodes().every(n=>!n.parent||allNodes().some(p=>p.id===n.parent)),'Parent references exist');
render();
