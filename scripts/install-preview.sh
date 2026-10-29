#!/bin/sh
# Stock macOS only. The GitHub tag/channel is trusted; checksum is not notarization.
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
LC_ALL=C
export LC_ALL
umask 077
fail() { echo "Relay installer: $*" >&2; exit 1; }
test "$#" -ge 1 && test "$#" -le 2 || fail 'usage: install-preview.sh vX.Y.Z-preview.N [Applications parent]'
v=$1
test "${#v}" -le 60 || fail 'version too long'
case "$v" in *[!a-zA-Z0-9.-]*) fail 'invalid version characters';; esac
printf '%s\n' "$v" | /usr/bin/grep -Eq '^v(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})-preview\.([1-9][0-9]{0,8})$' || fail 'invalid preview version'
test "$(/usr/bin/uname -m)" = arm64 || fail 'Apple Silicon required'
os=$(/usr/bin/sw_vers -productVersion)
major=${os%%.*}
test "$major" -ge 14 || fail 'macOS 14+ required'
core=${v#v}; core=${core%-preview.*}; counter=${v##*.}
parent=${2:-"$HOME/Applications"}
case "$parent" in /*) ;; *) fail 'absolute Applications parent required';; esac
# Check every component without resolving away symlinks. System ancestors may be
# root owned; the selected parent must be owned by this user and not group writable.
safe_parent() {
    /usr/bin/osascript -l JavaScript - "$parent" "$(/usr/bin/id -u)" <<'PARENT'
ObjC.import('Foundation');
function run(a) {
 const fm=$.NSFileManager.defaultManager, uid=Number(a[1]);
 const parts=a[0].split('/'); let p='';
 if(parts.some((x,i)=>i>0 && (!x || x==='.' || x==='..'))) throw Error('noncanonical parent');
 for(let i=1;i<parts.length;i++) {
  p+='/'+parts[i]; let at=fm.attributesOfItemAtPathError(p,null);
  if(!at) throw Error('missing parent component');
  if(ObjC.unwrap(at.objectForKey('NSFileType'))!=='NSFileTypeDirectory') throw Error('linked/non-directory parent');
  const owner=Number(ObjC.unwrap(at.objectForKey('NSFileOwnerAccountID'))), mode=Number(ObjC.unwrap(at.objectForKey('NSFilePosixPermissions')));
  if((owner!==0 && owner!==uid) || (mode & 18)) throw Error('unsafe parent ownership/mode');
  if(i===parts.length-1 && owner!==uid) throw Error('parent not user-owned');
 }
}
PARENT
}
if test "$parent" = "$HOME/Applications" && ! test -e "$parent" && ! test -L "$parent"; then
    # HOME itself must pass before creating only this one missing component.
    saved=$parent; parent=$HOME; safe_parent; parent=$saved
    /bin/mkdir -m 700 "$parent"
fi
safe_parent
final=$parent/Relay.app
test ! -e "$final" && test ! -L "$final" || fail 'Relay.app already exists; no overwrite'
stage=$(/usr/bin/mktemp -d "$parent/.relay-install.XXXXXXXX")
pid=; watch=
cleanup() {
    if test -n "$watch"; then kill "$watch" 2>/dev/null || :; wait "$watch" 2>/dev/null || :; fi
    if test -n "$pid"; then kill -KILL "$pid" 2>/dev/null || :; wait "$pid" 2>/dev/null || :; fi
    /bin/rm -rf -- "$stage"
}
trap cleanup 0
trap 'exit 1' 1 2 15
archive=Relay-$v-macos-arm64.zip
base=https://github.com/l0lxl0lw/ai-usage-monitor/releases/download/$v
download() {
    (ulimit -f "$3"; exec /usr/bin/curl --fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 --connect-timeout 15 --max-time 120 --max-filesize "$4" --output "$2" "$1")
    test "$(/usr/bin/wc -c < "$2")" -le "$4" || fail 'download too large'
}
download "$base/$archive" "$stage/$archive" 262144 268435456
download "$base/$archive.sha256" "$stage/checksum" 1 256
digest=$(/usr/bin/shasum -a 256 < "$stage/$archive"); digest=${digest%% *}
printf '%s  %s\n' "$digest" "$archive" > "$stage/expected"
/usr/bin/cmp -s "$stage/expected" "$stage/checksum" || fail 'checksum/name/record mismatch'
cat > "$stage/zip.js" <<'ZIP_VALIDATOR'
ObjC.import('Foundation');
function run(argv) {
 const cap=268435456, fm=$.NSFileManager.defaultManager;
 const at=fm.attributesOfItemAtPathError(argv[0],null);
 if(!at || ObjC.unwrap(at.objectForKey('NSFileType'))!=='NSFileTypeRegular') throw Error('archive type');
 const size=Number(ObjC.unwrap(at.objectForKey('NSFileSize')));
 if(size<22 || size>cap) throw Error('archive size');
 const h=$.NSFileHandle.fileHandleForReadingAtPath(argv[0]); if(!h) throw Error('archive open');
 let budget=0;
 function need(ok) { if(!ok) throw Error('unsupported ZIP metadata'); }
 function read(o,n) {
  need(Number.isSafeInteger(o)&&Number.isSafeInteger(n)&&o>=0&&n>=0&&n<=65536&&o+n<=size);
  budget+=n; need(budget<=262144); h.seekToFileOffset(o);
  const d=h.readDataOfLength(n); need(Number(d.length)===n);
  // Bounded base64 conversion avoids unsafe pointers and abbreviated descriptions.
  const text=ObjC.unwrap(d.base64EncodedStringWithOptions(0)), alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let b=[],value=0,bits=0;
  for(let i=0;i<text.length&&text[i]!=='=';i++) {
   const x=alphabet.indexOf(text[i]); need(x>=0); value=(value<<6)|x; bits+=6;
   if(bits>=8) { bits-=8; b.push((value>>>bits)&255); }
  }
  need(b.length===n); return b;
 }
 function u16(b,o) { return b[o]+256*b[o+1]; }
 function u32(b,o) { return u16(b,o)+65536*u16(b,o+2); }
 function sig(b,s) { need(u32(b,0)===s); }
 function extras(b,local) {
  let p=0,seen={};
  while(p<b.length) {
   need(p+4<=b.length); const id=u16(b,p), n=u16(b,p+2); p+=4;
   need(!seen[id]&&p+n<=b.length);
   if(id===0x5855) {
    need(n===(local?12:8)); // two uint32 timestamps; local uint16 uid/gid
    need(u32(b,p)<=0xffffffff&&u32(b,p+4)<=0xffffffff);
    if(local) need(u16(b,p+8)<=65535&&u16(b,p+10)<=65535);
   } else if(id===0x5455) {
    const flags=b[p]; need(n>=5 && (flags&~7)===0 && (flags&1)===1);
    need(n===(local?1+4*((flags&1?1:0)+(flags&2?1:0)+(flags&4?1:0)):5));
   } else if(id===0x7875) {
    need(n===11&&b[p]===1&&b[p+1]===4&&b[p+6]===4);
   } else need(false);
   seen[id]=b.slice(p,p+n); p+=n;
  }
  return seen;
 }
 const names=['Relay.app/','Relay.app/Contents/','Relay.app/Contents/MacOS/','Relay.app/Contents/_CodeSignature/','Relay.app/Contents/Info.plist','Relay.app/Contents/MacOS/Relay','Relay.app/Contents/MacOS/relay-bridge','Relay.app/Contents/_CodeSignature/CodeResources'];
 try {
  const e=read(size-22,22); sig(e,0x06054b50);
  need(u16(e,4)===0&&u16(e,6)===0&&u16(e,8)===8&&u16(e,10)===8&&u16(e,20)===0);
  const cs=u32(e,12),co=u32(e,16); need(cs<=65536&&co+cs===size-22);
  let p=co,total=0,seen={},ranges=[];
  for(let i=0;i<8;i++) {
   const c=read(p,46); sig(c,0x02014b50);
   const made=u16(c,4),ver=u16(c,6),flags=u16(c,8),method=u16(c,10),crc=u32(c,16),compressed=u32(c,20),plain=u32(c,24),nl=u16(c,28),el=u16(c,30),off=u32(c,42);
   need((made>>8)===3&&[10,20,21].indexOf(made&255)>=0&&(ver===10||ver===20)&&!(flags&~0x0808)&&(method===0||method===8));
   need((method!==8&&!(flags&8))||ver===20);
   need(nl>0&&nl<=128&&el<=4096&&u16(c,32)===0&&u16(c,34)===0&&u16(c,36)===0);
   need(p+46+nl+el<=co+cs);
   const raw=read(p+46,nl), name=String.fromCharCode.apply(null,raw);
   need(names.indexOf(name)>=0&&!seen[name]); seen[name]=true;
   const dir=name.endsWith('/'), attr=u32(c,38),mode=Math.floor(attr/65536);
   need((mode&0xf000)===(dir?0x4000:0x8000)&&!(mode&0xe12)&&(dir?[0,16,0x4000]:[0,0x4000]).indexOf(attr&65535)>=0);
   need(plain<=cap&&compressed<=cap&&(plain===0||compressed>0&&plain<=compressed*200));
   if(dir) need(plain===0&&compressed===0&&crc===0&&method===0&&!(flags&8));
   if(method===0) need(plain===compressed);
   total+=plain; need(total<=536870912); const ce=extras(read(p+46+nl,el),false);
   const l=read(off,30); sig(l,0x04034b50);
   need(u16(l,4)===ver&&u16(l,6)===flags&&u16(l,8)===method&&u32(l,10)===u32(c,12));
   const ln=u16(l,26),le=u16(l,28); need(ln===nl&&le<=4096);
   need(read(off+30,ln).every((v,j)=>v===raw[j])); const lex=extras(read(off+30+ln,le),true);
   need(Object.keys(ce).sort().join(',')===Object.keys(lex).sort().join(','));
   Object.keys(ce).forEach(id=>{
    const n=Number(id)===0x5455?5:ce[id].length;
    need(ce[id].slice(0,n).every((v,j)=>v===lex[id][j]));
   });
   let end=off+30+ln+le+compressed; need(end<=co);
   if(flags&8) {
    need(!dir&&u32(l,14)===0&&u32(l,18)===0&&u32(l,22)===0);
    const d=read(end,16); sig(d,0x08074b50);
    need(u32(d,4)===crc&&u32(d,8)===compressed&&u32(d,12)===plain); end+=16;
   } else need(u32(l,14)===crc&&u32(l,18)===compressed&&u32(l,22)===plain);
   need(end<=co); ranges.push([off,end]); p+=46+nl+el;
  }
  need(p===co+cs&&Object.keys(seen).length===8);
  ranges.sort((a,b)=>a[0]-b[0]); let end=0;
  ranges.forEach(r=>{need(r[0]===end&&r[1]>r[0]);end=r[1];}); need(end===co);
  need(Number(h.seekToEndOfFile)===size);
 } finally { h.closeFile; }
}
ZIP_VALIDATOR
# Bound diagnostic files using the kernel even on old curl/osascript. Watchdog
# bounds elapsed time; wait's real exit status is never hidden by cleanup.
bounded_jxa() {
    (ulimit -f 16; exec /usr/bin/osascript -l JavaScript "$@") > "$stage/jxa.out" 2> "$stage/jxa.err" &
    pid=$!
    (
        sleeper=
        trap 'test -z "$sleeper" || kill "$sleeper" 2>/dev/null || :; exit 0' 1 2 15
        sleep 30 & sleeper=$!
        wait "$sleeper" || exit 0
        kill -KILL "$pid" 2>/dev/null || :
    ) > /dev/null 2>&1 & watch=$!
    result=0; wait "$pid" || result=$?
    pid=
    kill "$watch" 2>/dev/null || :
    wait "$watch" 2>/dev/null || :
    watch=
    test "$result" -eq 0 || fail 'bounded metadata/native operation failed'
    test "$(wc -c < "$stage/jxa.out")" -le 16384 && test "$(wc -c < "$stage/jxa.err")" -le 16384 || fail 'diagnostic cap'
}
bounded_jxa "$stage/zip.js" "$stage/$archive"
/usr/bin/unzip -t "$stage/$archive" > "$stage/integrity" 2>&1 || fail 'ZIP integrity error'
# unzip emits diagnostics for unsupported/trailing/mismatched structures as well
# as CRC failures; all metadata was already checked above.
/usr/bin/grep -Eiq 'warning|error:|bad CRC|mismatch' "$stage/integrity" && fail 'ZIP warning'
/bin/mkdir "$stage/extracted"
/usr/bin/ditto -x -k "$stage/$archive" "$stage/extracted"
app=$stage/extracted/Relay.app
cat > "$stage/inventory.js" <<'INVENTORY'
ObjC.import('Foundation');
function run(a) {
 const fm=$.NSFileManager.defaultManager, root=a[0];
 const expected=['Contents','Contents/Info.plist','Contents/MacOS','Contents/MacOS/Relay','Contents/MacOS/relay-bridge','Contents/_CodeSignature','Contents/_CodeSignature/CodeResources'];
 const top=fm.attributesOfItemAtPathError(root,null);
 if(!top || ObjC.unwrap(top.objectForKey('NSFileType'))!=='NSFileTypeDirectory'||(Number(ObjC.unwrap(top.objectForKey('NSFilePosixPermissions')))&0xe12)) throw Error('app root type/mode');
 const enumerator=fm.enumeratorAtPath(root); let item, found=[], total=0, inventory=[];
 while((item=ObjC.unwrap(enumerator.nextObject))!==undefined && item!==null) {
  if(found.length>=7||expected.indexOf(item)<0) throw Error('unexpected member');
  const at=fm.attributesOfItemAtPathError(root+'/'+item,null),type=ObjC.unwrap(at.objectForKey('NSFileType'));
  const dir=expected.indexOf(item)===0||item==='Contents/MacOS'||item==='Contents/_CodeSignature';
  const mode=Number(ObjC.unwrap(at.objectForKey('NSFilePosixPermissions'))),size=Number(ObjC.unwrap(at.objectForKey('NSFileSize')));
  if(type!==(dir?'NSFileTypeDirectory':'NSFileTypeRegular')||(mode&0xe12)) throw Error('member type/mode');
  if(!dir) { total+=size; if(size>268435456||total>536870912||Number(ObjC.unwrap(at.objectForKey('NSFileReferenceCount')))!==1) throw Error('member size/link'); }
  if(item.startsWith('Contents/MacOS/') && !(mode&73)) throw Error('nonexecutable');
  found.push(item);
  inventory.push([item,type,mode,size]);
 }
 if(found.length!==7) throw Error('incomplete inventory');
 return JSON.stringify(inventory.sort((x,y)=>x[0].localeCompare(y[0])));
}
INVENTORY
validate_app() {
    bounded_jxa "$stage/inventory.js" "$1"
    /bin/cp "$stage/jxa.out" "$stage/inventory"
    plist=$1/Contents/Info.plist
    for key in CFBundleIdentifier CFBundleExecutable CFBundlePackageType CFBundleShortVersionString CFBundleVersion LSMinimumSystemVersion; do
        test "$(/usr/bin/plutil -type "$key" "$plist")" = string
    done
    test "$(/usr/bin/plutil -type LSUIElement "$plist")" = bool
    test "$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$plist")" = org.relay.monitor
    test "$(/usr/bin/plutil -extract CFBundleExecutable raw -o - "$plist")" = Relay
    test "$(/usr/bin/plutil -extract CFBundlePackageType raw -o - "$plist")" = APPL
    test "$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$plist")" = "$core"
    test "$(/usr/bin/plutil -extract CFBundleVersion raw -o - "$plist")" = "$counter"
    test "$(/usr/bin/plutil -extract LSMinimumSystemVersion raw -o - "$plist")" = 14.0
    test "$(/usr/bin/plutil -extract LSUIElement raw -o - "$plist")" = true
    for signed in "$1/Contents/MacOS/Relay" "$1/Contents/MacOS/relay-bridge" "$1"; do
        /usr/bin/codesign --verify --strict "$signed"
        /usr/bin/codesign -d -vv "$signed" > "$stage/signature" 2>&1
        /usr/bin/grep -q '^Signature=adhoc$' "$stage/signature"
        /usr/bin/grep -q '^TeamIdentifier=not set$' "$stage/signature"
        case "$signed" in
            */Contents/MacOS/relay-bridge) /usr/bin/grep -Eq '^Identifier=relay-bridge-[a-fA-F0-9]+$' "$stage/signature";;
            *) /usr/bin/grep -q '^Identifier=org.relay.monitor$' "$stage/signature";;
        esac
    done
}
hashes() {
    (cd "$1"; /usr/bin/shasum -a 256 Contents/Info.plist Contents/MacOS/Relay Contents/MacOS/relay-bridge Contents/_CodeSignature/CodeResources)
}
validate_app "$app"
/bin/cp "$stage/inventory" "$stage/before-inventory"
hashes "$app" > "$stage/before"
identity=$(/usr/bin/stat -f '%d:%i' "$app")
cat > "$stage/promote.js" <<'PROMOTE'
ObjC.import('Foundation');
ObjC.bindFunction('renamex_np', ['int', ['char *', 'char *', 'unsigned int']]);
function run(argv) {
 if(argv.length!==2 || $.renamex_np(argv[0],argv[1],4)!==0) throw Error('exclusive rename failed');
}
PROMOTE
safe_parent
bounded_jxa "$stage/promote.js" "$app" "$final"
test ! -e "$app" && test ! -L "$app" || fail 'source still present'
test ! -L "$final" && test "$(/usr/bin/stat -f '%d:%i' "$final")" = "$identity" || fail 'promotion identity mismatch'
validate_app "$final"
/usr/bin/cmp -s "$stage/before-inventory" "$stage/inventory" || fail 'promotion inventory mismatch'
hashes "$final" > "$stage/after"
/usr/bin/cmp -s "$stage/before" "$stage/after" || fail 'promotion content mismatch'
echo "Installed $final (not launched; ad-hoc signed, not notarized)."
