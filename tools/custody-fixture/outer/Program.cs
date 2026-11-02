using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

// Separate watchdog for the synthetic inner watchdog and all its descendants.
// Unbuilt and unrun: review source, platform support, and exact binaries first.
internal static class Program {
 static readonly string Root=Path.Combine(Path.GetFullPath(Environment.GetEnvironmentVariable("RUNNER_TEMP")??throw new Exception("runner_temp_missing")),"civ13-custody");
 const string Dotnet=@"C:\Program Files\dotnet\dotnet.exe";
 static string DotnetHash="";
 [StructLayout(LayoutKind.Sequential)] struct StartupInfo { public uint cb; public IntPtr reserved,desktop,title; public uint x,y,xsize,ysize,xcount,ycount,fill,flags; public ushort show,reserved2; public IntPtr reservedPtr,stdin,stdout,stderr; }
 [StructLayout(LayoutKind.Sequential)] struct StartupInfoEx { public StartupInfo startup;public IntPtr attributes; }
 [StructLayout(LayoutKind.Sequential)] struct ProcessInfo { public IntPtr process,thread;public uint pid,tid; }
 [StructLayout(LayoutKind.Sequential)] struct BasicLimit { public long processTime,jobTime;public uint flags;public UIntPtr minWs,maxWs;public uint active;public UIntPtr affinity;public uint priority,scheduling; }
 [StructLayout(LayoutKind.Sequential)] struct IoCounters { public ulong r1,r2,r3,r4,r5,r6; }
 [StructLayout(LayoutKind.Sequential)] struct ExtendedLimit { public BasicLimit basic;public IoCounters io;public UIntPtr processMemory,jobMemory,peakProcess,peakJob; }
 [StructLayout(LayoutKind.Sequential)] struct Accounting { public long u,k,pu,pk;public uint faults,total,active,terminated; }
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateJobObjectW(IntPtr a,string? n);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetInformationJobObject(IntPtr j,int c,ref ExtendedLimit i,uint n);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool QueryInformationJobObject(IntPtr j,int c,ref Accounting i,uint n,out uint ret);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool TerminateJobObject(IntPtr j,uint code);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool InitializeProcThreadAttributeList(IntPtr p,int count,int flags,ref UIntPtr bytes);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool UpdateProcThreadAttribute(IntPtr p,uint flags,UIntPtr key,IntPtr value,UIntPtr size,IntPtr prev,IntPtr ret);
 [DllImport("kernel32.dll")] static extern void DeleteProcThreadAttributeList(IntPtr p);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateProcessW(string app,StringBuilder cmd,IntPtr pa,IntPtr ta,bool inherit,uint flags,IntPtr env,string cwd,ref StartupInfoEx start,out ProcessInfo process);
 [DllImport("kernel32.dll",SetLastError=true)] static extern uint WaitForSingleObject(IntPtr h,uint ms);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetExitCodeProcess(IntPtr h,out uint code);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool CloseHandle(IntPtr h);
 static string Hash(string p){using var f=File.OpenRead(p);using var h=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);byte[] b=new byte[65536];long total=0;while(true){int n=f.Read(b,0,b.Length);if(n==0)break;total+=n;if(total>67108864)throw new Exception("hash_limit");h.AppendData(b,0,n);}return Convert.ToHexString(h.GetHashAndReset()).ToLowerInvariant();}
 static byte[] BoundedRead(string p,int limit){using var f=File.OpenRead(p);byte[] b=new byte[limit+1];int used=0;while(used<b.Length){int n=f.Read(b,used,b.Length-used);if(n==0)break;used+=n;}if(used>limit)throw new Exception("read_limit");Array.Resize(ref b,used);return b;}
 static string Q(string s){if(s.IndexOfAny(new[]{'"','\0','\r','\n'})>=0||s.EndsWith('\\'))throw new Exception("argument");return "\""+s+"\"";}
 static bool NoReparse(string p){DirectoryInfo? d=new(Path.GetFullPath(p));while(d!=null){if((d.Attributes&FileAttributes.ReparsePoint)!=0)return false;d=d.Parent;}return true;}
 static void ExactKeys(JsonElement obj,params string[] required){
  if(obj.ValueKind!=JsonValueKind.Object)throw new Exception("receipt_object");
  var names=new HashSet<string>(StringComparer.Ordinal);
  foreach(var item in obj.EnumerateObject())if(!names.Add(item.Name))throw new Exception("receipt_duplicate");
  if(names.Count!=required.Length||required.Any(x=>!names.Contains(x)))throw new Exception("receipt_keys");
 }
 static JsonDocument ReadReceipt(string path,int limit){
  var info=new FileInfo(path);if(info.Length<2||info.Length>limit||(info.Attributes&FileAttributes.ReparsePoint)!=0)throw new Exception("receipt_size");
  return JsonDocument.Parse(BoundedRead(path,limit),new JsonDocumentOptions{MaxDepth=8});
 }
 static void VerifyReceipts(string scratch){
  using var inner=ReadReceipt(Path.Combine(scratch,"watchdog-result.json"),4096);var w=inner.RootElement;
  ExactKeys(w,"schema","exit","parent_exit","query","active","timeout","forced","cleanup_uncertain","error");
  if(w.GetProperty("schema").GetInt32()!=1||w.GetProperty("exit").GetInt32()!=0||w.GetProperty("parent_exit").GetUInt32()!=0||!w.GetProperty("query").GetBoolean()||w.GetProperty("active").GetUInt32()!=0||w.GetProperty("timeout").GetBoolean()||w.GetProperty("forced").GetBoolean()||w.GetProperty("cleanup_uncertain").GetBoolean()||w.GetProperty("error").GetString()!="none")throw new Exception("inner_receipt");
  using var report=ReadReceipt(Path.Combine(scratch,"coordinator-result.json"),16384);var r=report.RootElement;ExactKeys(r,"schema","cases");
  if(r.GetProperty("schema").GetInt32()!=1)throw new Exception("case_schema");
  var cases=r.GetProperty("cases");if(cases.ValueKind!=JsonValueKind.Array||cases.GetArrayLength()!=2)throw new Exception("case_count");
  var modes=new[]{("case-register","registration"),("case-clock","clock")};int i=0;
  foreach(var c in cases.EnumerateArray()){
   ExactKeys(c,"case","mode","held_before_unwind","held_during_unwind","released","job_closed","job_quiescent","root_exit","pipe_closed_before_fixture_cleanup","pipe_closed_after_fixture_cleanup","drain_threads_joined","same_error","active_after","inflight_after","spawn_attempts","failure");
   if(c.GetProperty("case").GetString()!=modes[i].Item1||c.GetProperty("mode").GetString()!=modes[i].Item2)throw new Exception("case_identity");i++;
   foreach(string k in new[]{"held_before_unwind","held_during_unwind","released","job_closed","job_quiescent","drain_threads_joined","same_error"})if(!c.GetProperty(k).GetBoolean())throw new Exception("case_evidence");
   foreach(string k in new[]{"active_after","inflight_after"})if(c.GetProperty(k).GetBoolean())throw new Exception("case_custody");
   if(c.GetProperty("root_exit").GetInt32()!=0||c.GetProperty("spawn_attempts").GetInt32()!=1||c.GetProperty("failure").ValueKind!=JsonValueKind.Null)throw new Exception("case_result");
   foreach(string k in new[]{"pipe_closed_before_fixture_cleanup","pipe_closed_after_fixture_cleanup"}){var a=c.GetProperty(k);if(a.ValueKind!=JsonValueKind.Array||a.GetArrayLength()!=2||a.EnumerateArray().Any(x=>!x.GetBoolean()))throw new Exception("case_pipes");}
  }
 }
 static void Main(string[] args){
  IntPtr job=IntPtr.Zero,attrs=IntPtr.Zero,jobArray=IntPtr.Zero,env=IntPtr.Zero;ProcessInfo pi=default;
  bool initialized=false,created=false,forced=false,attempted=false,query=false,timeout=false,uncertain=false,scratchValidated=false;uint active=uint.MaxValue,innerExit=uint.MaxValue;int result=1;string error="none",scratch="";
  try {
   // args: fresh scratch, exact reviewed inner DLL, DLL SHA256, manifest SHA256.
   if(args.Length!=5||!Regex.IsMatch(args[2],"^[0-9a-f]{64}$")||!Regex.IsMatch(args[3],"^[0-9a-f]{64}$")||!Regex.IsMatch(args[4],"^[0-9a-f]{64}$"))throw new Exception("arguments");
   scratch=Path.GetFullPath(args[0]);string runs=Path.Combine(Root,"runs");
   if(!StringComparer.OrdinalIgnoreCase.Equals(Path.GetDirectoryName(scratch),runs)||!Regex.IsMatch(Path.GetFileName(scratch),"^run-[0-9a-f]{32}$")||!NoReparse(scratch)||Directory.EnumerateFileSystemEntries(scratch).Any())throw new Exception("scratch");
   scratchValidated=true;
   string runtimePath=Path.Combine(Root,"runtime.json");if(Hash(runtimePath)!=args[4])throw new Exception("runtime_manifest_hash");
   using(var runtime=JsonDocument.Parse(BoundedRead(runtimePath,16384))){
    if(!StringComparer.OrdinalIgnoreCase.Equals(runtime.RootElement.GetProperty("dotnet").GetString(),Dotnet))throw new Exception("dotnet_path");
    DotnetHash=runtime.RootElement.GetProperty("dotnet_sha256").GetString()??throw new Exception("dotnet_hash");
   }
   string dll=Path.GetFullPath(args[1]);string expectedDll=Path.Combine(Root,"watchdog","bin","Release","net8.0","CustodyWatchdog.dll");
   if(!StringComparer.OrdinalIgnoreCase.Equals(dll,expectedDll)||!NoReparse(Path.GetDirectoryName(dll)!)||(File.GetAttributes(dll)&FileAttributes.ReparsePoint)!=0||Hash(dll)!=args[2]||Hash(Dotnet)!=DotnetHash)throw new Exception("binary_pin");
   job=CreateJobObjectW(IntPtr.Zero,null);if(job==IntPtr.Zero)throw new Exception("job_create");
   var limits=new ExtendedLimit();limits.basic.flags=0x2000|0x8|0x100|0x200;limits.basic.active=3;limits.processMemory=(UIntPtr)(512UL*1024*1024);limits.jobMemory=(UIntPtr)(1536UL*1024*1024);
   if(!SetInformationJobObject(job,9,ref limits,(uint)Marshal.SizeOf<ExtendedLimit>()))throw new Exception("job_limits");
   UIntPtr size=UIntPtr.Zero;InitializeProcThreadAttributeList(IntPtr.Zero,1,0,ref size);if(size==UIntPtr.Zero||size.ToUInt64()>65536)throw new Exception("attribute_size");
   attrs=Marshal.AllocHGlobal(checked((int)size.ToUInt64()));if(!InitializeProcThreadAttributeList(attrs,1,0,ref size))throw new Exception("attribute_init");initialized=true;
   jobArray=Marshal.AllocHGlobal(IntPtr.Size);Marshal.WriteIntPtr(jobArray,job);if(!UpdateProcThreadAttribute(attrs,0,(UIntPtr)0x2000d,jobArray,(UIntPtr)IntPtr.Size,IntPtr.Zero,IntPtr.Zero))throw new Exception("job_attribute");
   var start=new StartupInfoEx();start.startup.cb=(uint)Marshal.SizeOf<StartupInfoEx>();start.attributes=attrs;
   var cmd=new StringBuilder(Q(Dotnet)+" "+Q(dll)+" "+Q(scratch)+" "+Q(args[3])+" "+Q(args[4]));
   var vars=new SortedDictionary<string,string>(StringComparer.OrdinalIgnoreCase){{"SystemRoot",@"C:\Windows"},{"WINDIR",@"C:\Windows"},{"PATH",Path.GetDirectoryName(Dotnet)!},{"TEMP",scratch},{"TMP",scratch},{"DOTNET_CLI_HOME",Root},{"DOTNET_NOLOGO","1"},{"DOTNET_CLI_TELEMETRY_OPTOUT","1"},{"DOTNET_SKIP_FIRST_TIME_EXPERIENCE","1"},{"RUNNER_TEMP",Path.GetDirectoryName(Root)!}};
   env=Marshal.StringToHGlobalUni(string.Join("\0",vars.Select(x=>x.Key+"="+x.Value))+"\0\0");
   if(!CreateProcessW(Dotnet,cmd,IntPtr.Zero,IntPtr.Zero,false,0x80000|0x400|0x08000000,env,scratch,ref start,out pi))throw new Exception("process_create");created=true;
   uint wait=WaitForSingleObject(pi.process,45000);
   if(wait==258){timeout=true;forced=true;attempted=true;if(!TerminateJobObject(job,124))uncertain=true;wait=WaitForSingleObject(pi.process,5000);}
   if(wait!=0)throw new Exception("inner_wait");if(!GetExitCodeProcess(pi.process,out innerExit)||innerExit==259)throw new Exception("inner_exit");
   var th=pi.thread;pi.thread=IntPtr.Zero;if(!CloseHandle(th))uncertain=true;
   var pr=pi.process;pi.process=IntPtr.Zero;if(!CloseHandle(pr))uncertain=true;
   var account=new Accounting();query=QueryInformationJobObject(job,1,ref account,(uint)Marshal.SizeOf<Accounting>(),out uint got)&&got==Marshal.SizeOf<Accounting>();if(query)active=account.active;
   if(!query||active!=0){if(!attempted){forced=true;attempted=true;if(!TerminateJobObject(job,125))uncertain=true;}throw new Exception("job_not_quiescent");}
   if(uncertain||forced||timeout||innerExit!=0)throw new Exception("inner_failed");VerifyReceipts(scratch);result=0;
  }catch(Exception e){error=e.Message;}
  finally {
   if(pi.thread!=IntPtr.Zero){var h=pi.thread;pi.thread=IntPtr.Zero;if(!CloseHandle(h))uncertain=true;}
   if(pi.process!=IntPtr.Zero){var h=pi.process;pi.process=IntPtr.Zero;if(!CloseHandle(h))uncertain=true;}
   if(initialized)DeleteProcThreadAttributeList(attrs);if(attrs!=IntPtr.Zero)Marshal.FreeHGlobal(attrs);if(jobArray!=IntPtr.Zero)Marshal.FreeHGlobal(jobArray);if(env!=IntPtr.Zero)Marshal.FreeHGlobal(env);
   if(job!=IntPtr.Zero){
    if(created&&active!=0&&!attempted){forced=true;attempted=true;if(!TerminateJobObject(job,126))uncertain=true;}
    if(created&&active!=0){var until=Stopwatch.StartNew();while(until.ElapsedMilliseconds<5000){var accounting=new Accounting();query=QueryInformationJobObject(job,1,ref accounting,(uint)Marshal.SizeOf<Accounting>(),out uint size)&&size==Marshal.SizeOf<Accounting>();if(!query){uncertain=true;break;}active=accounting.active;if(active==0)break;Thread.Sleep(25);}if(active!=0)uncertain=true;}
    if(!CloseHandle(job))uncertain=true;
   }
   if(uncertain)result=1;
   if(scratchValidated)try{var b=Encoding.UTF8.GetBytes(JsonSerializer.Serialize(new{schema=1,result,inner_exit=innerExit,query,active,forced,timeout,cleanup_uncertain=uncertain,error}));if(b.Length>4096)throw new Exception();using var f=new FileStream(Path.Combine(scratch,"outer-result.json"),FileMode.CreateNew,FileAccess.Write,FileShare.None);f.Write(b);f.Flush(true);}catch{result=1;}
   Environment.ExitCode=result;
  }
 }
}
