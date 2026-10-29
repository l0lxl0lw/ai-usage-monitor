"""Synthetic Git/GitHub responses exercise the actual future publisher logic."""
import copy
import hashlib
import importlib.util
from pathlib import Path
import subprocess

spec=importlib.util.spec_from_file_location('publisher',Path(__file__).with_name('publish-preview.py'))
pub=importlib.util.module_from_spec(spec);spec.loader.exec_module(pub)


def policy(ref='refs/tags/v*-preview.*'):
    return dict(target='tag',enforcement='active',bypass_actors=[],conditions={'ref_name':{'include':[ref],'exclude':[]}},rules=[{'type':'update'},{'type':'deletion'}])


class Fake(pub.GitHub):
    def __init__(self,directory,tag,mode=''):
        self.directory,self.tag,self.mode=directory,tag,mode
        self.guards=0;self.policy_reads=0;self.writes=[];self.release=None;self.payloads={}

    def identity(self,*args):
        self.guards+=1
        if self.mode=='identity' or self.mode=='prewrite-tag' and self.guards==2 or self.mode=='postwrite-tag' and self.guards==3:
            raise ValueError('tag changed')

    def policies(self):
        self.policy_reads+=1
        if self.mode=='postwrite-policy' and self.policy_reads==3: return []
        if self.mode=='prewrite-policy' and self.policy_reads==2: return []
        return [policy()]

    def api(self,path,missing=False):
        if path.endswith('/latest'): return self.release if self.mode=='latest' else None
        return self.release

    def command(self,args,**kwargs):
        if args[:3]==['gh','release','create']:
            assert '--verify-tag' in args and '--prerelease' in args and '--latest=false' in args
            self.writes.append(args);self.release=dict(id=1,tag_name=self.tag,target_commitish='a'*40,draft=False,prerelease=True,assets=[])
        elif args[:3]==['gh','release','upload']:
            assert '--clobber' not in args
            self.writes.append(args)
            if self.mode=='partial-upload': raise subprocess.CalledProcessError(1,args)
            file=Path(args[4]);i=len(self.payloads)+1;self.payloads[i]=file.read_bytes()
            self.release['assets'].append(dict(id=i,name=file.name,state='uploaded',size=file.stat().st_size))
        elif args[:2]==['gh','api']:
            return self.payloads[int(args[-1].split('/')[-1])]
        else: raise AssertionError(args)
        return b''


def suite(directory,tag):
    count=0
    for ref in ['refs/tags/v*-preview.*','refs/tags/'+tag,'~ALL']:
        pub.protected([policy(ref)],tag);count+=1
    parameterized=policy();parameterized['rules'][0]['parameters']={'update_allows_fetch_and_merge':False}
    pub.protected([parameterized],tag);count+=1
    for value in [True,0,None]:
        bad=copy.deepcopy(parameterized);bad['rules'][0]['parameters']['update_allows_fetch_and_merge']=value
        try: pub.protected([bad],tag)
        except ValueError: count+=1
        else: raise AssertionError('update exception/untyped parameter')
    invalid=[[],[dict(policy(),enforcement='disabled')],[dict(policy(),enforcement='evaluate')],[dict(policy(),bypass_actors=[{'actor_id':1}])],[dict(policy(),rules=[{'type':'update'}])],[dict(policy(),rules=[{'type':'deletion'}])],[dict(policy(),conditions={})],[dict(policy(),target='unknown')],[dict(policy(),conditions={'ref_name':{'include':['refs/tags/*'],'exclude':[]}})],[dict(policy(),conditions={'ref_name':{'include':['~ALL'],'exclude':['refs/tags/v*']}})]]
    incomplete=policy();del incomplete['bypass_actors'];invalid.append([incomplete])
    for policies in invalid:
        try: pub.protected(policies,tag)
        except ValueError: count+=1
        else: raise AssertionError('unsafe policy accepted')
    # Real inherited-detail traversal and pagination, missing/incomplete/source errors.
    class Details(pub.GitHub):
        def api(self,path,missing=False):
            if '?' in path: return [{'id':7,'source':pub.REPO,'source_type':'Repository'},{'id':8,'source':pub.REPO.split('/')[0],'source_type':'Organization'}]
            return dict(policy(),id=int(path.split('/')[-1]))
    assert len(Details().policies())==2
    class Identity(pub.GitHub):
        def __init__(self,mode=''): self.mode=mode;self.commands=[]
        def command(self,args,**kwargs):
            self.commands.append(args)
            if args[1]=='fetch': return b''
            if args[1]=='merge-base':
                if self.mode=='off-main': raise subprocess.CalledProcessError(1,args)
                return b''
            if args[-1].endswith('^{commit}'): return (('c' if self.mode=='peeled' else 'a')*40+'\n').encode()
            return (('c' if self.mode=='object' else 'b')*40+'\n').encode()
    identity=Identity();identity.identity(tag,'a'*40,'b'*40)
    assert identity.commands[0][1:4]==['fetch','--no-tags','origin']
    for mode in ['object','peeled','off-main']:
        try: Identity(mode).identity(tag,'a'*40,'b'*40)
        except (ValueError,subprocess.CalledProcessError): count+=1
        else: raise AssertionError('actual identity guard '+mode)
    class BrokenDetails(pub.GitHub):
        def __init__(self,mode): self.mode=mode
        def api(self,path,missing=False):
            if self.mode=='unreadable': raise ValueError('unreadable API')
            if '?' in path:
                if self.mode=='partial': return {}
                if self.mode=='pagination': return [{'id':7,'source':pub.REPO,'source_type':'Repository'}]*100
                if self.mode=='source': return [{'id':7,'source':'unexpected','source_type':'Repository'}]
                return [{'id':7,'source':pub.REPO,'source_type':'Repository'}]
            return dict(policy(),id=8 if self.mode=='detail' else 7)
    for mode in ['unreadable','partial','pagination','source','detail']:
        try: BrokenDetails(mode).policies()
        except ValueError: count+=1
        else: raise AssertionError('actual full-policy traversal '+mode)
    api=Fake(directory,tag);assert 'created' in pub.publish(api,tag,'a'*40,'b'*40,directory,'push','refs/tags/'+tag)
    assert len(api.writes)==3 and api.guards==8
    writes=len(api.writes);assert 'no-op' in pub.publish(api,tag,'a'*40,'b'*40,directory,'push','refs/tags/'+tag);assert len(api.writes)==writes
    for mode in ['identity','prewrite-tag','postwrite-tag','prewrite-policy','postwrite-policy','partial-upload']:
        failing=Fake(directory,tag,mode)
        try: pub.publish(failing,tag,'a'*40,'b'*40,directory,'push','refs/tags/'+tag)
        except (ValueError,subprocess.CalledProcessError): count+=1
        else: raise AssertionError(mode)
        assert all('delete' not in x and '--clobber' not in x for x in failing.writes)
    for mutation in ['draft','stable','tag','target','extra','missing','bytes','latest','state','size']:
        bad=Fake(directory,tag);bad.release=copy.deepcopy(api.release);bad.payloads=copy.deepcopy(api.payloads)
        if mutation=='draft': bad.release['draft']=True
        if mutation=='stable': bad.release['prerelease']=False
        if mutation=='tag': bad.release['tag_name']='v2.0.0-preview.1'
        if mutation=='target': bad.release['target_commitish']='c'*40
        if mutation=='extra': bad.release['assets'].append(dict(id=3,name='extra'))
        if mutation=='missing': bad.release['assets'].pop()
        if mutation=='bytes': bad.payloads[1]=b'wrong'
        if mutation=='latest': bad.mode='latest'
        if mutation=='state': bad.release['assets'][0]['state']='new'
        if mutation=='size': bad.release['assets'][0]['size']+=1
        try: pub.publish(bad,tag,'a'*40,'b'*40,directory,'push','refs/tags/'+tag)
        except ValueError: count+=1
        else: raise AssertionError(mutation)
        assert not bad.writes
    for event,ref in [('pull_request','refs/tags/'+tag),('pull_request_target','refs/tags/'+tag),('push','refs/heads/main')]:
        bad=Fake(directory,tag)
        try: pub.publish(bad,tag,'a'*40,'b'*40,directory,event,ref)
        except ValueError: count+=1
        else: raise AssertionError('unsafe event')
        assert bad.guards==0 and not bad.writes
    print(f'Future publisher synthetic cases: {count+4}; no GitHub writes')
