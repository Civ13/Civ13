namespace Robust.Shared.Maths {
 public struct Vector2i {public int X,Y;public static implicit operator Vector2i((int,int) v)=>new(){X=v.Item1,Y=v.Item2};}
 public struct Vector2u {public uint X,Y;public Vector2u(uint x,uint y){X=x;Y=y;}}
}
namespace OpenDreamShared.Dream {public enum AtomDirection : byte {None=0,North=1,South=2,East=4,West=8,Northeast=5,Southeast=6,Northwest=9,Southwest=10}}
