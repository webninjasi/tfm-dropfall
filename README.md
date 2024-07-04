
# dropfall (open to new name suggestions)

## XML Reference

```xml
<C>
  <P reload="" mapname="Custom Mapname Text" speczone="x,y" image="mouse.png,scaleX,scaleY" kitchensink="checkpoint.png,scaleX,scaleY" size="mouseSize" bgcolor="FF00FF"/>
  <Z>
    <S>
      <S T="0" X="421" Y="372" L="665" H="76" P="0,0,0.3,0.2,0,0,0,0" contact="id" boost="vx,vy,wind,gravity" explosion="power,radius,miceOnly"/>
    </S>
    <D/>
    <O>
      <O X="138" Y="204" C="22" P="0"/>
      <O X="230" Y="147" C="22" P="0"/>
    </O>
    <L>
      <JD c="ffffff,10,0.9," P1="303,276.5" P2="650,282.5" tp="vx,vy,relative"/>
    </L>
  </Z>
</C>
```

- P
  - reload: tells script to load the map's XML so it can exceed ground/object limits
  - mapname: custom map name text that appears at the top left corner of the game
  - speczone: where the spectators will stay (!spec command)
  - image: custom image to change player appearances
  - kitchensink: enables checkpoint/parkour mode, you can specify a custom checkpoint image optionally
  - size: default mouse size
  - bgcolor: background color in hex code
- S
  - contact: allows the script to detect mouse-ground contacts, need to specify a unique number here
  - boost: booster parameters to use on contact
    - vx, vy = velocity/speed
    - wind, gravity = changes wind/gravity for the player that contacts the ground, map should have at least 0.01 wind or gravity for respective effect to be applied for the player
  - explosion: creates a spirit like explosion at the point the player touches the ground
    - power: explosion power
    - radius: radius of explosion
    - miceOnly: should affect only mice, otherwise affects objects
- JD
  - tp: creates an entrance portal at P1 and exit portal at P2, players exit with specified velocity/speed (vx,vy)
