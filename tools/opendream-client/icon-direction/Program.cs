using OpenDreamShared.Resources;
using OpenDreamShared.Dream;
var count=0;
void Assert(bool test,string message){count++;if(!test)throw new Exception(message);}
var selected=new DMIParser.ParsedDMIState("");
var frame=new DMIParser.ParsedDMIFrame{X=7,Y=9};
selected.Directions[AtomDirection.South]=[frame];
foreach(var dir in new[]{AtomDirection.South,AtomDirection.North,AtomDirection.East,AtomDirection.West}){
 var inserted=selected.GetFrames(dir,null,false);
 Assert(inserted.ContainsKey(dir),"destination direction preserved");
 Assert(inserted[dir].Length==1 && ReferenceEquals(inserted[dir][0],frame),"normalized SOUTH frame must insert into each cardinal direction");
 var constructed=selected.GetFrames(dir,null,true);
 Assert(constructed.ContainsKey(AtomDirection.South) && constructed[AtomDirection.South].Length==1,"constructor normalized direction");
}
Assert(selected.GetFrames(AtomDirection.North,2)[AtomDirection.North].Length==0,"missing frame stays empty");
var multi=new DMIParser.ParsedDMIState("");multi.Directions[AtomDirection.South]=[frame];multi.Directions[AtomDirection.North]=[frame];
Assert(multi.GetFrames(AtomDirection.West,null,false)[AtomDirection.West].Length==0,"multi-direction missing direction must stay empty");
Assert(selected.GetFrames(null,null,false).Count==1,"all-direction copy does not invent frames");
Console.WriteLine($"PASS {count} directional frame assertions");

