// Execute this expression in the mock page context. Restores the initial sample.
(() => {
  const results=[];
  const check=(name,ok)=>{results.push({name,pass:Boolean(ok)});if(!ok)throw Error(name)};
  const click=selector=>{const el=document.querySelector(selector);if(!el)throw Error(`Missing ${selector}`);el.click()};
  const change=(id,value)=>{document.getElementById(id).value=value;document.getElementById(id).dispatchEvent(new Event('change'))};
  const search=value=>{document.getElementById('search').value=value;document.getElementById('search').dispatchEvent(new Event('input'))};
  const saved=projects.map(p=>p.nodes.map(n=>({...n,events:n.events.map(e=>[...e])})));
  try {
    check('Single popover surface, no separate dashboard',document.querySelectorAll('main').length===1&&document.querySelector('main').id==='popover'&&!document.getElementById('activity-view'));
    check('Usage opens with four independent accounts',document.querySelectorAll('.account-card').length===4);
    check('Pro has only its reported weekly meter',document.querySelectorAll('.account-card')[1].querySelectorAll('[role="meter"]').length===1);
    click('[data-account="claude-work"]');
    check('Account details replace list inside popover',state.route.type==='account'&&document.getElementById('screen-title').textContent==='Claude / Work'&&!document.querySelector('.account-card'));
    check('Stale quota notice is explicit',document.querySelector('.notice').textContent.includes('Last-known'));
    click('[data-agent="docs-main"]');
    check('Account to associated agent navigation',state.route.id==='docs-main'&&document.querySelector('.task-text').textContent.includes('12 minutes'));
    click('#back');check('Back returns to account',state.route.type==='account');
    click('#back');check('Back returns to usage',state.route.type==='usage'&&state.stack.length===0);
    click('#agents-tab');
    check('Agent tab shows correct counts',JSON.stringify([...document.querySelectorAll('.stat strong')].map(n=>Number(n.textContent)))==='[4,1,3]');
    check('Collapsible parent/child hierarchy',Boolean(document.querySelector('[data-agent="schema"]')));
    click('[data-collapse="provider"]');check('Collapse hides descendant',!document.querySelector('[data-agent="schema"]'));
    click('[data-collapse="provider"]');
    search('schema');check('Search preserves two ancestors',document.querySelectorAll('.agent-row').length===3&&document.getElementById('list-info').textContent.startsWith('1 matching'));
    search('unlikely-session-name');check('No-match state',document.querySelector('.empty h2').textContent==='No matching agents');
    click('#restore');change('status-filter','waiting');
    check('State filter retains root context',document.querySelectorAll('.agent-row').length===2);
    change('status-filter','all');change('project-filter','docs');click('[data-collapse="docs-main"]');
    check('Unknown parent is shown without a fabricated edge',document.querySelector('[data-agent="docs-test"]').textContent.includes('Parent unknown')&&!document.querySelector('[data-agent="docs-test"]').closest('.agent-row').classList.contains('child'));
    click('[data-agent="docs-test"]');check('Unattributed agent stays unknown',document.querySelector('.fact-list').textContent.includes('Model does not identify a billing account'));
    click('#back');change('project-filter','all');click('[data-agent="provider"]');click('[data-agent="orchestrator"]');
    check('Parent navigation stays in popover',state.route.id==='orchestrator'&&document.getElementById('tabs').hidden);
    click('#back');check('Nested back restores child detail',state.route.id==='provider');
    click('#settings');change('scenario','offline');
    check('Offline changes menu to last known',document.getElementById('menu-count').textContent.includes('last known')&&document.getElementById('advance').disabled);
    click('#back');check('Offline agent detail notice',document.querySelector('.notice').textContent.includes('last known'));
    click('#settings');change('scenario','empty');click('#back');
    // Existing detail snapshots can remain readable; root list reflects the empty scenario.
    while(state.stack.length)back();switchTab('agents');
    check('Empty collector yields zero counts',document.querySelector('.empty h2').textContent==='No sessions observed'&&[...document.querySelectorAll('.stat strong')].every(n=>n.textContent==='0'));
    click('#restore');click('#settings');
    document.getElementById('show-done').checked=false;document.getElementById('show-done').dispatchEvent(new Event('change'));click('#back');
    check('Completed visibility recalculates matching count',document.getElementById('list-info').textContent.startsWith('6 matching'));
    click('#advance');check('Demo event updates working count',document.getElementById('menu-count').textContent==='5 working');
    switchTab('usage');click('#needs-input');check('Usage shortcut navigates within same popup',state.route.type==='agents');
    click('#settings');document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape'}));check('Escape first goes back',state.route.type==='agents'&&!document.getElementById('popover').hidden);
    document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape'}));check('Escape at root closes popover',document.getElementById('popover').hidden);
    click('#menu-trigger');check('Menu reopens the same surface',!document.getElementById('popover').hidden);
    check('No horizontal viewport overflow',document.documentElement.scrollWidth<=innerWidth);
    check('Content stays within the compact shell',document.getElementById('popover').getBoundingClientRect().width<=420&&document.getElementById('content').scrollHeight>=document.getElementById('content').clientHeight);
  } finally {
    projects.forEach((p,i)=>p.nodes=saved[i]);Object.assign(state,{tab:'usage',route:{type:'usage'},stack:[],query:'',project:'all',status:'all',collapsed:new Set(['docs-main','release-main']),showDone:true,scenario:'sample',step:0,scrolls:new Map()});document.getElementById('popover').hidden=false;document.getElementById('menu-trigger').setAttribute('aria-expanded','true');document.getElementById('toast').hidden=true;render();document.getElementById('content').scrollTop=0;
  }
  return {passed:results.filter(r=>r.pass).length,total:results.length,results};
})()
