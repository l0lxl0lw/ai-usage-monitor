// Fictional fixtures only. Nothing here is collected from a real account or session.
const accounts = [
  {id:'claude-personal',provider:'Claude',alias:'Personal',tier:'Max',source:'CLI telemetry',age:'18s ago',windows:[{label:'5-hour',used:72,reset:'Resets in 1h 24m'},{label:'Weekly',used:48,reset:'Resets Fri, 10:00'}]},
  {id:'codex-work',provider:'Codex',alias:'Work',tier:'Pro',source:'App-server',age:'32s ago',windows:[{label:'Weekly',used:21,reset:'Resets Mon, 09:00'}],note:'No 5-hour window reported'},
  {id:'claude-work',provider:'Claude',alias:'Work',tier:'Max',source:'CLI telemetry',age:'12m ago',stale:true,windows:[{label:'5-hour',used:91,reset:'Resets in 38m'},{label:'Weekly',used:67,reset:'Resets Sat, 14:00'}]},
  {id:'codex-personal',provider:'Codex',alias:'Personal',tier:'Plus',source:'App-server',age:'32s ago',windows:[{label:'5-hour',used:38,reset:'Resets in 3h 12m'},{label:'Weekly',used:64,reset:'Resets Sun, 11:00'}]},
];
const projects = [
  {id:'usage',name:'ai-usage-monitor',branch:'feat/menu-bar',nodes:[
    {id:'orchestrator',parent:null,name:'Build menu-bar monitor',role:'Coordinator',source:'Orca',model:'Claude',account:'claude-personal',state:'working',elapsed:'24m',task:'Coordinating provider adapters and the native menu-bar popover.',events:[['10:42','Waiting for provider research'],['10:39','Spawned UI implementation agent'],['10:18','Session started']]},
    {id:'provider',parent:'orchestrator',name:'Provider adapters',role:'Implementation',source:'OpenCode',model:'Claude',account:null,state:'working',elapsed:'18m',task:'Implementing isolated usage adapters without sharing account credentials.',events:[['10:41','Reading rate-limit protocol'],['10:37','Spawned schema research agent'],['10:24','Assigned by coordinator']]},
    {id:'schema',parent:'provider',name:'Usage schema research',role:'Research',source:'OpenCode',model:'Codex',account:null,state:'done',elapsed:'6m',task:'Verified optional windows, usage units, and reset timestamp formats.',events:[['10:40','Research returned'],['10:37','Compared response fields'],['10:34','Assigned by Provider adapters']]},
    {id:'shell',parent:'orchestrator',name:'Menu-bar shell',role:'Implementation',source:'Codex',model:'Codex',account:'codex-work',state:'working',elapsed:'9m',task:'Building nested navigation entirely inside the menu-bar popover.',events:[['10:42','Laying out account usage rows'],['10:38','Added keyboard navigation'],['10:33','Assigned by coordinator']]},
    {id:'review',parent:'orchestrator',name:'Privacy & permissions',role:'Review',source:'Claude Code',model:'Claude',account:'claude-personal',state:'waiting',elapsed:'4m',task:'Needs a decision: should session titles be remembered between app launches?',events:[['10:42','Requested a retention decision'],['10:40','Checked privacy boundaries'],['10:38','Assigned by coordinator']]},
  ]},
  {id:'docs',name:'docs-site',branch:'fix/navigation',nodes:[
    {id:'docs-main',parent:null,name:'Repair mobile navigation',role:'Session',source:'Claude Code',model:'Claude',account:'claude-work',state:'idle',elapsed:'41m',task:'Session is open, with no current observed turn. Last seen 12 minutes ago.',events:[['10:30','Session became idle'],['10:28','Received test results'],['10:01','Session started']]},
    {id:'docs-test',parent:null,memberOf:'docs-main',unknownParent:true,name:'Browser regression checks',role:'Testing',source:'Claude Code',model:'Claude',account:null,state:'done',elapsed:'7m',task:'Observed in the docs session. Its immediate parent agent was not reported.',events:[['10:28','Observed agent stop'],['10:21','Observed session membership']]},
  ]},
  {id:'cli',name:'release-cli',branch:'chore/release',nodes:[
    {id:'release-main',parent:null,name:'Prepare release notes',role:'Coordinator',source:'Codex',model:'Codex',account:'codex-personal',state:'working',elapsed:'12m',task:'Summarizing merged changes for the next CLI release.',events:[['10:42','Combining change summaries'],['10:37','Received changelog research'],['10:30','Session started']]},
    {id:'release-research',parent:'release-main',name:'Changelog research',role:'Research',source:'Codex',model:'Codex',account:'codex-personal',state:'done',elapsed:'5m',task:'Grouped changes by user-visible behavior.',events:[['10:37','Returned change summary'],['10:34','Read merged pull requests']]},
    {id:'release-check',parent:'release-main',name:'Version consistency',role:'Testing',source:'Codex',model:'Codex',account:'codex-personal',state:'done',elapsed:'3m',task:'Compared package versions and release metadata.',events:[['10:39','Finished consistency check'],['10:37','Compared version fields']]},
  ]},
];
