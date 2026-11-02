using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

// Synthetic-only watchdog. Unbuilt and unrun; exact build output requires review.
internal static class Program
{
    static readonly string Root = Path.Combine(Path.GetFullPath(Environment.GetEnvironmentVariable("RUNNER_TEMP") ?? throw new Exception("runner_temp_missing")),"civ13-custody");
    static string Python="", PythonSha="";
    const uint WaitObject = 0, WaitTimeout = 258;
    [StructLayout(LayoutKind.Sequential)] struct StartupInfo {
        public uint cb; public IntPtr reserved, desktop, title;
        public uint x,y,xsize,ysize,xcount,ycount,fill,flags; public ushort show,reserved2;
        public IntPtr reservedPtr,stdin,stdout,stderr;
    }
    [StructLayout(LayoutKind.Sequential)] struct StartupInfoEx { public StartupInfo startup; public IntPtr attributes; }
    [StructLayout(LayoutKind.Sequential)] struct ProcessInfo { public IntPtr process, thread; public uint pid, tid; }
    [StructLayout(LayoutKind.Sequential)] struct BasicLimit {
        public long processTime,jobTime; public uint flags; public UIntPtr minWs,maxWs;
        public uint active; public UIntPtr affinity; public uint priority,scheduling;
    }
    [StructLayout(LayoutKind.Sequential)] struct IoCounters { public ulong r1,r2,r3,r4,r5,r6; }
    [StructLayout(LayoutKind.Sequential)] struct ExtendedLimit {
        public BasicLimit basic; public IoCounters io; public UIntPtr processMemory,jobMemory,peakProcess,peakJob;
    }
    [StructLayout(LayoutKind.Sequential)] struct Accounting {
        public long u,k,pu,pk; public uint faults,total,active,terminated;
    }
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr CreateJobObjectW(IntPtr a,string? n);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetInformationJobObject(IntPtr j,int c,ref ExtendedLimit i,uint n);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool QueryInformationJobObject(IntPtr j,int c,ref Accounting i,uint n,out uint ret);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool TerminateJobObject(IntPtr j,uint code);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool InitializeProcThreadAttributeList(IntPtr p,int count,int flags,ref UIntPtr bytes);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool UpdateProcThreadAttribute(IntPtr p,uint flags,UIntPtr key,IntPtr value,UIntPtr size,IntPtr prev,IntPtr ret);
    [DllImport("kernel32.dll")] static extern void DeleteProcThreadAttributeList(IntPtr p);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool CreateProcessW(string app,StringBuilder cmd,IntPtr pa,IntPtr ta,bool inherit,uint flags,IntPtr env,string cwd,ref StartupInfoEx start,out ProcessInfo process);
    [DllImport("kernel32.dll", SetLastError=true)] static extern uint WaitForSingleObject(IntPtr h,uint ms);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetExitCodeProcess(IntPtr h,out uint code);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool CloseHandle(IntPtr h);
    static string Hash(string p){using var f=File.OpenRead(p);using var h=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);byte[] b=new byte[65536];long total=0;while(true){int n=f.Read(b,0,b.Length);if(n==0)break;total+=n;if(total>67108864)throw new Exception("hash_limit");h.AppendData(b,0,n);}return Convert.ToHexString(h.GetHashAndReset()).ToLowerInvariant();}
 static byte[] BoundedRead(string p,int limit){using var f=File.OpenRead(p);byte[] b=new byte[limit+1];int used=0;while(used<b.Length){int n=f.Read(b,used,b.Length-used);if(n==0)break;used+=n;}if(used>limit)throw new Exception("read_limit");Array.Resize(ref b,used);return b;}
    static string Q(string s) { if(s.IndexOfAny(new[]{'"','\0','\r','\n'})>=0 || s.EndsWith('\\')) throw new Exception("unsafe_argument"); return "\""+s+"\""; }
    static bool LocalNoReparse(string path) {
        var item=new DirectoryInfo(Path.GetFullPath(path));
        while(item!=null) { if((item.Attributes&FileAttributes.ReparsePoint)!=0)return false; item=item.Parent; }
        return true;
    }
    static void VerifyManifest(string manifest,string expected) {
        var info=new FileInfo(manifest);
        if(info.Length>16384 || (info.Attributes&FileAttributes.ReparsePoint)!=0 || !Regex.IsMatch(expected,"^[0-9a-f]{64}$") || Hash(manifest)!=expected)throw new Exception("manifest_hash");
        using var doc=JsonDocument.Parse(BoundedRead(manifest,16384));
        if(doc.RootElement.EnumerateObject().Count()!=2 || doc.RootElement.GetProperty("schema").GetInt32()!=1)throw new Exception("manifest_schema");
        string snapshot=Path.Combine(Root,"snapshot")+Path.DirectorySeparatorChar;
        if(!LocalNoReparse(snapshot))throw new Exception("snapshot_reparse");
        var files=doc.RootElement.GetProperty("files").EnumerateObject().ToArray();
        if(files.Length<1||files.Length>16)throw new Exception("manifest_count");
        var names=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach(var item in files) {
            if(item.Name.Length>160||!Regex.IsMatch(item.Name,@"^[A-Za-z0-9_./-]+$")||item.Name.Contains("..")||!names.Add(item.Name))throw new Exception("manifest_path");
            string f=Path.GetFullPath(Path.Combine(snapshot,item.Name.Replace('/',Path.DirectorySeparatorChar)));
            var member=new FileInfo(f);
            if(!f.StartsWith(snapshot,StringComparison.OrdinalIgnoreCase)||member.Length>1048576||(member.Attributes&FileAttributes.ReparsePoint)!=0||!LocalNoReparse(member.DirectoryName!)||!Regex.IsMatch(item.Value.GetString()??"","^[0-9a-f]{64}$")||Hash(f)!=item.Value.GetString())throw new Exception("manifest_member");
        }
    }
    static void Main(string[] args) {
        int exit=1; IntPtr job=IntPtr.Zero, attrs=IntPtr.Zero, jobArray=IntPtr.Zero, env=IntPtr.Zero;
        ProcessInfo pi=default; bool attrInit=false, forced=false, timeout=false, query=false, created=false, terminationAttempted=false, cleanupUncertain=false, scratchValidated=false; uint active=uint.MaxValue,parentExit=uint.MaxValue;
        string scratch="";string error="none";
        try {
            if(args.Length!=3||!Regex.IsMatch(args[1],"^[0-9a-f]{64}$")||!Regex.IsMatch(args[2],"^[0-9a-f]{64}$"))throw new Exception("arguments");
            scratch=Path.GetFullPath(args[0]);string runs=Path.Combine(Root,"runs")+Path.DirectorySeparatorChar;
            if(!scratch.StartsWith(runs,StringComparison.OrdinalIgnoreCase)||!StringComparer.OrdinalIgnoreCase.Equals(Path.GetDirectoryName(scratch),runs.TrimEnd(Path.DirectorySeparatorChar))||!Regex.IsMatch(Path.GetFileName(scratch),"^run-[0-9a-f]{32}$")||!LocalNoReparse(scratch))throw new Exception("scratch");
            if(Directory.EnumerateFileSystemEntries(scratch).Any())throw new Exception("scratch_not_empty");
   scratchValidated=true;
            VerifyManifest(Path.Combine(Root,"snapshot","manifest.json"),args[1]);
            string runtimePath=Path.Combine(Root,"runtime.json");
            if(Hash(runtimePath)!=args[2])throw new Exception("runtime_manifest_hash");
            using(var runtime=JsonDocument.Parse(BoundedRead(runtimePath,16384))){
                Python=runtime.RootElement.GetProperty("python").GetString()??throw new Exception("python_path");
                PythonSha=runtime.RootElement.GetProperty("python_sha256").GetString()??throw new Exception("python_hash");
            }
            if(!Path.IsPathFullyQualified(Python)||!Regex.IsMatch(PythonSha,"^[0-9a-f]{64}$")||Hash(Python)!=PythonSha)throw new Exception("python_hash");
            job=CreateJobObjectW(IntPtr.Zero,null);if(job==IntPtr.Zero)throw new Exception("job_create");
            var limits=new ExtendedLimit();limits.basic.flags=0x2000|0x8|0x100|0x200;limits.basic.active=2;
            limits.processMemory=(UIntPtr)(512UL*1024*1024);limits.jobMemory=(UIntPtr)(1024UL*1024*1024);
            if(!SetInformationJobObject(job,9,ref limits,(uint)Marshal.SizeOf<ExtendedLimit>()))throw new Exception("job_limits");
            UIntPtr size=UIntPtr.Zero;InitializeProcThreadAttributeList(IntPtr.Zero,1,0,ref size);
            if(size==UIntPtr.Zero||size.ToUInt64()>65536)throw new Exception("attribute_size");
            attrs=Marshal.AllocHGlobal(checked((int)size.ToUInt64()));
            if(!InitializeProcThreadAttributeList(attrs,1,0,ref size))throw new Exception("attribute_init");attrInit=true;
            jobArray=Marshal.AllocHGlobal(IntPtr.Size);Marshal.WriteIntPtr(jobArray,job);
            if(!UpdateProcThreadAttribute(attrs,0,(UIntPtr)0x2000d,jobArray,(UIntPtr)IntPtr.Size,IntPtr.Zero,IntPtr.Zero))throw new Exception("job_attribute");
            var start=new StartupInfoEx();start.startup.cb=(uint)Marshal.SizeOf<StartupInfoEx>();start.attributes=attrs;
            string script=Path.Combine(Root,"snapshot","coordinator.py");
            var cmd=new StringBuilder(Q(Python)+" -I -S -B "+Q(script)+" "+Q(scratch));
            var variables=new SortedDictionary<string,string>(StringComparer.OrdinalIgnoreCase) {
                ["SystemRoot"]=@"C:\Windows",["WINDIR"]=@"C:\Windows",["PATH"]=Path.GetDirectoryName(Python)!,
                ["TEMP"]=scratch,["TMP"]=scratch,["PYTHONDONTWRITEBYTECODE"]="1",["PYTHONNOUSERSITE"]="1",
                ["RUNNER_TEMP"]=Path.GetDirectoryName(Root)!,["CUSTODY_RUNTIME_SHA256"]=args[2]};
            string block=string.Join("\0",variables.Select(x=>x.Key+"="+x.Value))+"\0\0";env=Marshal.StringToHGlobalUni(block);
            if(!CreateProcessW(Python,cmd,IntPtr.Zero,IntPtr.Zero,false,0x80000|0x400|0x08000000,env,scratch,ref start,out pi))throw new Exception("process_create");
            created=true;
            uint wait=WaitForSingleObject(pi.process,32000);
            if(wait==WaitTimeout){timeout=true;forced=true;terminationAttempted=true;if(!TerminateJobObject(job,124))throw new Exception("terminate_failed");wait=WaitForSingleObject(pi.process,5000);}
            if(wait!=WaitObject)throw new Exception("root_wait");
            if(!GetExitCodeProcess(pi.process,out parentExit)||parentExit==259)throw new Exception("root_exit");
            var thread=pi.thread;pi.thread=IntPtr.Zero;if(!CloseHandle(thread)){cleanupUncertain=true;throw new Exception("thread_close");}
            var process=pi.process;pi.process=IntPtr.Zero;if(!CloseHandle(process)){cleanupUncertain=true;throw new Exception("process_close");}
            var until=Stopwatch.StartNew();
            while(until.ElapsedMilliseconds<5000){
                var account=new Accounting();query=QueryInformationJobObject(job,1,ref account,(uint)Marshal.SizeOf<Accounting>(),out uint got)&&got==Marshal.SizeOf<Accounting>();
                if(!query)throw new Exception("job_query");active=account.active;if(active==0)break;Thread.Sleep(25);
            }
            if(active!=0){forced=true;terminationAttempted=true;if(!TerminateJobObject(job,125))cleanupUncertain=true;throw new Exception("job_not_quiescent");}
            if(parentExit!=0||timeout||forced||!query)throw new Exception("coordinator_failed");
            exit=0;
        } catch(Exception ex) { error=ex.Message; }
        finally {
            if(pi.thread!=IntPtr.Zero){var h=pi.thread;pi.thread=IntPtr.Zero;if(!CloseHandle(h))cleanupUncertain=true;}
            if(pi.process!=IntPtr.Zero){var h=pi.process;pi.process=IntPtr.Zero;if(!CloseHandle(h))cleanupUncertain=true;}
            if(attrInit)DeleteProcThreadAttributeList(attrs);
            if(attrs!=IntPtr.Zero)Marshal.FreeHGlobal(attrs);if(jobArray!=IntPtr.Zero)Marshal.FreeHGlobal(jobArray);if(env!=IntPtr.Zero)Marshal.FreeHGlobal(env);
            if(job!=IntPtr.Zero){
                if(created&&active!=0&&!terminationAttempted){forced=true;terminationAttempted=true;if(!TerminateJobObject(job,126))cleanupUncertain=true;}
                if(created&&active!=0){var cleanup=Stopwatch.StartNew();while(cleanup.ElapsedMilliseconds<5000){var a=new Accounting();query=QueryInformationJobObject(job,1,ref a,(uint)Marshal.SizeOf<Accounting>(),out uint n)&&n==Marshal.SizeOf<Accounting>();if(!query){cleanupUncertain=true;break;}active=a.active;if(active==0)break;Thread.Sleep(25);}if(active!=0)cleanupUncertain=true;}
                if(!CloseHandle(job))cleanupUncertain=true;
            }
            if(cleanupUncertain)exit=1;
            if(scratchValidated)try{
                var body=JsonSerializer.Serialize(new {schema=1,exit,parent_exit=parentExit,query,active,timeout,forced,cleanup_uncertain=cleanupUncertain,error});
                if(Encoding.UTF8.GetByteCount(body)>4096)throw new Exception();
                using var file=new FileStream(Path.Combine(scratch,"watchdog-result.json"),FileMode.CreateNew,FileAccess.Write,FileShare.None);
                byte[] bytes=Encoding.UTF8.GetBytes(body);file.Write(bytes);file.Flush(true);
            }catch{exit=1;}
            Environment.ExitCode=exit;
        }
    }
}
