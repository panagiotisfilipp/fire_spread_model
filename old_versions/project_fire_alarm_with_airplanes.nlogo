__includes [ "communication.nls"];;βιβλιοθηκη για μηνύματα πρακτόρων
extensions [gis sound]

breed [fires fire] ;; bright red turtles -- the leading edge of the fire
breed [embers ember] ;; turtles gradually fading from red to near black
breed [ashes ash]
breed[airplanes airplane];αεροσκάφη κατάσβεσης πυρκαγιάς
breed[airbases airbase];Βαση αεροσκαφών
breed[sensors sensor];Σενσορες

airplanes-own [incoming-queue status  water ];ουρές μηνυμάτων αεροσκαφών και ποσοτητα νερου που φέρουν πανω τους
sensors-own [incoming-queue status state];ουρές μηνυμάτων σενσορς,anixneusi sensor


; -----------------------------------------------------------------------------------
globals [view autoburn burnday today tslb-dataset  dem-dataset
    veg-dataset wetness-dataset burnt2015-dataset cliff-dataset
    burnt-area
    result ;μεταβλητη με την οποια σταματαει το μοντέλο
    border land
    randburn
    night timeofday tod iteration timeod
  wsv cws windran wd wd-1 wd-2 wd-3 wd-4 wd-5 wd-6 wd-7 direction ember-fly-dist]
patches-own
[ab burntab
  Wetness
  elevation
  burnt
  veg
  burnt2015
  tslb
  slope
  wind
  burnablity
  burnttime
  fuelload
  topowet
  SAVED-IGNITION out1 totalout]

;******************** To setup αεροπλάνων κτλ
to setup1
  clear
   set result 0
   ;δημιουργία βάσης αφών
   ask patch 0 0  [set pcolor 120]
   ask patch 1 1  [set pcolor 120]
   ask patch -1 -1  [set pcolor 120]
   ask patch -1 1  [set pcolor 120]
   ask patch -1 0  [set pcolor 120]
   ask patch 0 1  [set pcolor 120]
   ask patch 0 0  [set pcolor 120]
   setup-sensors
   setup-airplanes

   setup-airbases
end
; -----------------------------------------------------------------------------------
to setup
  __clear-all-and-reset-ticks

  set-default-shape turtles "circle"
  set view "Hill Shade"
  set night night = 0
  set-time-of-day
  ask patches [set wind 1]
  ask patches [set burnttime 1]
  set border patches with [ count neighbors != 8 ]
  setup-patches
  set land patches with [ elevation > 1 ]
  ask patches [set-fuelload]

  clear
end
; -----------------------------------------------------------------------------------
;Δημιουργία Βάσης αεροπλάνων
to setup-airbases
    create-airbases 1[
     ask patch-here [set pcolor blue]
     setxy 0 0
      set color blue
      set label "Airbase"
      set size 18
    ]


end
; -----------------------------------------------------------------------------------
;Δημιουργία αεροπλάνων
to setup-airplanes

    ;dimiourgia aeroplanon
   create-airplanes number-of-airplanes [
     set shape "airplane"
     set color blue
     setxy 0 0
     set size 22
     set water initial-water
     set incoming-queue []
     set status "stand-by"

   ]
end

;Δημιουργία αισθητήρων
to setup-sensors
   ;Οικισμός
   create-sensors 1 [
     set shape "alarm"
     set size 22
     set label "sensor-0"
     setxy 24 143
     set incoming-queue []
     set status "scanning"
     set state 0


]
      ;Πόλη 1
     create-sensors 1 [
     set shape "alarm"
     set size 22
     set label "sensor-1"
     setxy -10 -140
     set incoming-queue []
     set status "scanning"
     set state 0

   ]


end
; -----------------------------------------------------------------------------------
;;αν ο sensor ανιχνευσει φωτιά μέσα σε ακτίνα 20 να θέσει την κατάσταση του σε firing και να στείλει μήνυμα στα αεροπλάνα
;αλλιώς να θέσει την κατάσταση του σε scanning και να ζητησει απο τα αεροπλάνα να επιστρέψουν στην βάση τους
to do_run_sensor

;;;;sensors
ask  sensors [

if any? sensors with [any? embers with [color = 45] in-radius 150  or any? embers with [color = 15] in-radius 150]   [
  ask sensors [set state 1]
  decide_to_do
 ]
]
 ask  sensors [
if not any? sensors with [any? embers with [color = 45] in-radius 150  or any? embers with [color = 15] in-radius 150] [
    ask sensors [set state 2]

   decide_to_do
   ]
]
end
; -----------------------------------------------------------------------------------
;decide_to_do
to decide_to_do
  ask sensors [
    if state = 1 [

  ask_airplane_to_send_sensor
    ]
  ]

ask sensors [
 if state = 2[
   ask_airplane_to_back_sensor
 ]
]
end

; -----------------------------------------------------------------------------------
;Ανέφερε την κατάσταση των αεροσκαφων στον χρήστη
to-report my-plane
  report [who] of one-of airplanes
end
; -----------------------------------------------------------------------------------
;αποστολή μηνυμάτων απο sensors  στα αεροπλάνα ανάλογα με την επικρατούσα κατάσταση
to ask_airplane_to_send_sensor
    send add-receiver my-plane add-content "fire!fire!fire!" create-message "request"
        ask sensors [set status "burning"]

end
; -----------------------------------------------------------------------------------
;αποστολή μηνυμάτων απο τους sensors στα αεροπλάνα ανάλογα με την επικρατούσα κατάσταση
to ask_airplane_to_back_sensor
    send add-receiver my-plane add-content "fire-stopped" create-message "request"
     ask sensors  [set status "scanning"]

end

; -----------------------------------------------------------------------------------
;Η βασική εργασία του αεροπλάνου.
;Ανάλογα με την κατάστασή του, αποφασίζει για την επόμενη κίνηση
;Aν τα αφη έχουν κατάσταση stand-by να διαβάσουν την ουρά μηνυμάτων
;Αν η κατάσταση των αφων είναι take-off και υπάρχει φωτιά να πάνε στην φωτιά με βήμα 5
;Aν η κατάσταη των αφων είναι return-to-base να επιστρέψουν στην βάση τους με βήμα 5
;Αν όλα τα αφη επιστέψουν στην βάση να σταματήσει το μοντέλο
; --------------------------------
to do_run_airplane

  ifelse status = "stand-by"
  [process-airplane-queue]


 [ if status = "take-off"
    [ move-to-fire]

    if status =  "return-to-base"
    [ move-to-base]
if status = "refill"
[do_water]
 ]

end
; -----------------------------------------------------------------------------------
;κίνηση αφων προς την φωτιά
to move-to-fire

  ifelse (any? embers with [color = 45] or any? embers with [color = 15]) and not (timeod = "evening" or timeod = "night" or timeod = "early morning" or timeod = "Dawn")
  [set heading towards one-of embers with [color = 45 or color = 15 or pcolor = 133]
  fd 5
  set result   0
  update-airplanes]
  [set status "return-to-base"]
end
; -----------------------------------------------------------------------------------
;επιστροφή αφων στην βάση τους
to move-to-base
  if ( not any? embers with [color = 45] or not any? embers with [color = 15])
[
   ask airplanes [set heading towards one-of airbases with [color = blue]]
   fd 5

  ask airbases
[ ask other airplanes
   [ let d DISTANCE myself
      if d <= 1
      [ ask airplanes[
     set status "stand-by"
     set result 1]
      ]
]
  ]
  ]
 if (any? embers with [color = 45] or any? embers with [color = 15]) and (timeod = "evening" or timeod = "night" or timeod = "Dawn" or timeod = "early morning")[
  ask airplanes [set heading towards one-of airbases with [color = blue]]
   fd 5

  ask airbases
[ ask other airplanes
   [ let d DISTANCE myself
      if d <= 1
      [ ask airplanes[
     set status "stand-by"
     set water initial-water
     ]
      ]
]
  ]
 ]
 if( not any? embers with [color = 45] or not any? embers with [color = 15]) and (timeod = "evening" or timeod = "night" or timeod = "Dawn" or timeod = "early morning") and status = "stand-by" and state = 2[
   set result 1]


end
; -----------------------------------------------------------------------------------


to process-airplane-queue
  ; Διαβασέ ένα μήνυμα από την ουρά
  ; Αν δεν υπάρχει μήνυμα στην ουρά, τότε τέλος ( [stop] )
  ; Αν το μήνυμα είναι "request" με content "fire fire fire" να θέσει την κατάσταση των αφων σε take-off
  ; Αν το μήνυμα είναι "request" με content "fire stopped" να θέσει την κατάσταση των αφων σε return-to-base
  let msg get-message

  if msg = "no_message" [stop]
  if get-performative msg = "request" and get-content msg = "fire!fire!fire!"  [
    if status = "stand-by" and not (timeod = "evening" or timeod = "night" or timeod = "Dawn" or timeod = "early morning")[
      set status "take-off"
    ]]
end
; -----------------------------------------------------------------------------------

; -----------------------------------------------------------------------------------
;Ανανέωση κίνησης αφών αν είναι στην γειτονία της φωτιάς να την σβήσουν και να αλλάζουν το χρώμα του background του χάρτη
to update-airplanes
if water > 0[
  ask embers with [color = 45 or color = 15][
    if (count airplanes-on  neighbors) >= 1 [
         ask airplanes
     [set water water - 1]
    set pcolor 133 die ;καθε patch που σβήνουν αλλάζει χρώμα και πεθαίνει


    ]
  ]]
if water <= 0[
ask airplanes [set status "refill"]
]

end
; -----------------------------------------------------------------------------------
;ποσοτητα νερου και επιστροφη στην βαση για ανεφοδιασμο
to do_water

 if (any? embers with [color = 45] or any? embers with [color = 15]) and  status = "refill"[

      ask airplanes [set heading towards one-of airbases with [color = blue]]
        fd 5
          ask airbases
[ ask other airplanes
  [ let d1 DISTANCE myself
      if d1 <= 1
      [ ask airplanes[
          wait 10
     set water initial-water
     set status  "stand-by"]
      ]
]
  ]
 ]


end


;*******************************************
;*******************************************clear and go συναρτήσεις
to clear
  clear-turtles
  reset-ticks
  set-time-of-day
  ask patches [set burnt 100]
  ask patches [set burnttime 1]
  view-new
end
; -----------------------------------------------------------------------------------
to go

    set night (ticks / 200) ;; Need To Change With Difference Spatial Resolution
    if  time-of-day [changeFire_Danger]
    ask border   [  ask turtles-here [ die ]  ]
    ask turtles  [calc-slope]
    ask turtles [calc-windinfluence]
    if ticks = 0 [set-windspeed ask patches [set-topowet]]
    ifelse just-wind [check-spread2] [check-spread]
    set burnt-area ((count patches with [burnt = 0]) * 0.0009) ;; Need To Change With Difference Spatial Resolution
    fade-embers
    if variable-wind [change-wind-speed]
    set tod tod + 1
    ;;if not any? turtles [save-iter]
    ;;*use this to make movie* movie-set-frame-rate 2 movie-grab-view
    ;change-wind-speed
    ask sensors [do_run_sensor]
    ask airplanes [do_run_airplane]
     tick
    update-labels
     if result = 1  [stop];συνθήκη που σταματάει το μόντελο

end

;***************************************************************************************
;***********************************CHECK FIRE SPREAD***********************************
;***************************************************************************************

to check-spread
    ask fires  ;;determines intial spread make probability lower to simultate rapid fire spred only under high burn conditions.
     [ ask neighbors [set randburn (random 30)]
          ask neighbors [ set burnablity  (fuelload * (((-0.039 * (Fire_Danger ^ 2)) + (Fire_Danger * 0.8) - 0.7)  * (topowet)))]
          ask neighbors with [ (randburn < ((burnablity * (wind * slope)))) and burnt = 100 ][ignite let ransnd random 20]
      ask neighbors with [(wind > 1) and randburn < 2] [let target-patch patch-at-heading-and-distance direction ((random ember-fly-dist) - 1) if target-patch != nobody [ignite]]
           set breed embers ]
ask embers
        [ ask neighbors [set randburn (random 35)]
          ask neighbors with [ ((randburn + (burnttime * 2.2)) < ((burnablity * (wind * slope )))) and burnt = 100 ][let ransnd random 20 ignite]]
end
;Wind only spread
to check-spread2
    ask fires
        [ ask neighbors [let ran1 random 25  set randburn (ran1 + 5)]
          ask neighbors with [ (randburn < (wind * Fire_Danger)  and burnt = 100 )][ignite]
           ask neighbors with [(wind > 2) and randburn < 4] [ask patch-at-heading-and-distance direction ((random ember-fly-dist) - 1) [ignite]]
           set breed embers ]
    ask embers
        [ ask neighbors [let ran1 random 40 set randburn (ran1 + 3)]
          ask neighbors with [ ((randburn + (burnttime * .2)) < (wind * Fire_Danger) and burnt = 100 )][ignite]]
end



;***************************************************************************************
;*************************************    IGNITION   ***********************************
;***************************************************************************************

to ignite
  sprout-fires 1
    [ set color 45     set burnt burnt - 100
      ]
  set pcolor black
end

;drop incendaries
to ignite-forest
;; light a fire where the user says to
  if (mouse-down?)
    [  ask patch mouse-xcor mouse-ycor
      [  sprout-fires 1
        [  set color 45
          ask patches in-cone 1 360
          [ sprout-fires 1
            [  set color 45
            ;;  set burnt burnt - 100   ]
                ]  ]]
        display      ]    ]
end

;re-ignite saved patches
to set-ignition
  ask patches with [SAVED-IGNITION = 1]
  [ sprout-fires 1 [set color 45 ]]
end



to fade-embers
  ask embers
    [ set  burnttime burnttime + 1
      if burnttime = 1 [set color  45]
      if burnttime = 2 [set color  45]
      if burnttime = 3 [set color  45]
      if burnttime = 4 [set  color 45]
      if burnttime = 5 [set color  25]
      if burnttime = 6 [set color  15]
      if burnttime = 7 [set color  27]
      if burnttime = 8 [set color  42]
      if burnttime = 9 [set  color 23]
      if burnttime = 10 [set color  26]
      if burnttime = 11 [set color  15]
      if burnttime = 12 [set color  24]
      if burnttime = 13 [set color  15]
      if burnttime > 60 / 3 and burnttime < 60 [set color  11]
      if burnttime > 20 and (pcolor != 133) [set pcolor 1 die]
      ]

end


;***************************************************************************************
;******************************BURNABILITY LAYER ADJUSTMENTS****************************
;***************************************************************************************

to set-topowet
  if (Fire_Danger < 4 and wetness  <= .9) [set topowet 1.1]
  if (Fire_Danger < 4 and wetness  > .9) [set topowet ((wetness * -0.75) + 1.675)]
  if (Fire_Danger > 3 and Fire_Danger < 6 and wetness  <= 1) [set topowet 1.1]
  if (Fire_Danger > 3 and Fire_Danger < 6 and wetness  > 1) [set topowet ((wetness * -0.75) + 1.75)]
  if (Fire_Danger > 5 and Fire_Danger < 8 and wetness  <= 1.1) [set topowet 1.1]
  if (Fire_Danger > 5 and Fire_Danger < 8 and wetness  > 1.1) [set topowet ((wetness * -0.75) + 1.825)]
  if (Fire_Danger = 8 and wetness  <= 1.2) [set topowet 1.1]
  if (Fire_Danger = 8 and wetness  > 1.2) [set topowet ((wetness * -0.75) + 1.9)]
  if (Fire_Danger > 8 and wetness  <= 1.3) [set topowet 1.1]
  if (Fire_Danger > 8 and wetness  > 1.3) [set topowet ((wetness * -0.75) + 1.975)]
end

to set-fuelload
   if veg = 1 [set fuelload ( (0.0011 * (tslb ^ 3)) + ( -0.0269 * (tslb ^ 2)) + ( 0.2086 * tslb) + 0.7) ]
   if veg = 2  [set fuelload 0.7 ]
   if veg = 3  [set fuelload 0.1 ]
   if veg = 4  [set fuelload 0.1 ]
   if veg = 5  [set fuelload 0.1 ]
   if veg = 6  [set fuelload 0.1 ]
      if veg = 7  [set fuelload 0.1 ]


end



;***************************************************************************************
;***********************************SLOPE***********************************************
;***************************************************************************************
;; Need To Change With Difference Spatial Resolution

to calc-slope ;;NTC - with differeing cell size
  ;; calulate slope from a burning pixel to surrounding pixeles using elevation data
   let e1  [elevation]  of patch-at 0 1
   let s1 (e1 - [elevation]  of patch-here) * 0.0016
   ask patch-at 0 1 [set slope ((-0.5148 * (s1 ^ 3)) + (0.1327 * (s1 ^ 2)) + ((0.7748 * s1) + 1))]

   let e2  [elevation]  of patch-at 1 0
   let s2 (e2 - [elevation]  of patch-here ) * 0.009
   ask patch-at 1 0 [set slope ((-0.5148 * (s2 ^ 3)) + (0.1327 * (s2 ^ 2)) + ((0.7748 * s2) + 1))]

   let e3  [elevation]  of patch-at 0 -1
   let s3 (e3 - [elevation]  of patch-here ) * 0.009
   ask patch-at 0 -1 [set slope ((-0.5148 * (s3 ^ 3)) + (0.1327 * (s3 ^ 2)) + ((0.7748 * s3) + 1))]

   let e4  [elevation]  of patch-at -1 0
   let s4 (e4 - [elevation]  of patch-here ) * 0.009
   ask patch-at -1 0 [set slope ((-0.5148 * (s4 ^ 3)) + (0.1327 * (s4 ^ 2)) + ((0.7748 * s4) + 1))]

   let e5  [elevation]  of patch-at 1 -1
   let s5 (e5 - [elevation]  of patch-here ) * 0.009
   ask patch-at 1 -1 [set slope ((-0.5148 * (s5 ^ 3)) + (0.1327 * (s5 ^ 2)) + ((0.7748 * s5) + 1))]

   let e6  [elevation]  of patch-at -1 -1
   let s6 (e6 - [elevation]  of patch-here ) * 0.009
   ask patch-at -1 -1 [set slope ((-0.5148 * (s6 ^ 3)) + (0.1327 * (s6 ^ 2)) + ((0.7748 * s6) + 1))]

   let e7  [elevation]  of patch-at 1 1
   let s7 (e7 - [elevation]  of patch-here ) * 0.009
   ask patch-at 1 -1 [set slope ((-0.5148 * (s7 ^ 3)) + (0.1327 * (s7 ^ 2)) + ((0.7748 * s7) + 1))]

   let e8  [elevation]  of patch-at -1 1
   let s8 (e8 - [elevation]  of patch-here ) * 0.009
   ask patch-at -1 -1 [set slope ((-0.5148 * (s8 ^ 3)) + (0.1327 * (s8 ^ 2)) + ((0.7748 * s8) + 1))]
end

;***************************************************************************************
;***********************************Time of Day***********************************************
;***************************************************************************************
;; Need To Change With Difference Spatial Resolution

to changeFire_Danger ;;NTC - with differeing cell size
      if tod > 400 [set tod 0 set night night + 1]
      if tod = 200 [set timeofday "night"
      if view = "Landsat" [import-pcolors-rgb "PNG/SAT_DHM_N.png"]
      if view = "Hill Shade" [import-pcolors-rgb "PNG/HS_DHM_N_greece.png"]
      if view = "Vegetation" [import-pcolors-rgb "PNG/LC_DHM_N.png"]
      ask patches [if (burnt < 100) [set pcolor black] ]]
      if tod = 200 and wsv > 1 [set wsv wsv - 1]
      if tod = 400 [set timeofday "day" set wsv wsv + 1
      if view = "Landsat" [import-pcolors-rgb "PNG/SAT_DHM.png"]
      if view = "Hill Shade" [import-pcolors-rgb "PNG/HS_DHM_greece.png"]
      if view = "Vegetation" [import-pcolors-rgb "PNG/LC_DHM.png"]
      ask patches [if (burnt < 100) [set pcolor black] ]]
      if tod = 0 [set Fire_Danger Fire_Danger - 1 set timeod "morning" ]
       if tod = 50 [set Fire_Danger Fire_Danger + 1 set timeod "noon"]
        if tod = 114 [set Fire_Danger Fire_Danger + 1 set timeod "afternoon"]
         if tod = 180  [set Fire_Danger Fire_Danger - 1 set timeod "evening"]
          if tod = 245 [set Fire_Danger Fire_Danger - 1 set timeod "evening"]
           if tod = 310 [set Fire_Danger Fire_Danger - 1 set timeod "early morning"]
            if tod = 355 [set Fire_Danger Fire_Danger - 1 set timeod "early morning"]
             if tod = 376 [set Fire_Danger Fire_Danger + 1 set timeod "Dawn"]
             if tod = 400 [set Fire_Danger Fire_Danger + 2 set timeod "early morning"]

end

To set-time-of-day
  if set-time = "morning" [set tod 1 set timeod "morning" set Fire_Danger Fire_Danger - 1]
    if set-time = "noon" [set tod 51 set timeod "noon"]
      if set-time = "afternoon" [set tod 115 set timeod "afternoon" set Fire_Danger Fire_Danger + 1]
        if set-time = "evening" [set tod 181  set timeod "evening"]
end





;***************************************************************************************
;***********************************WIND INFLUENCE**************************************
;***************************************************************************************

to set-windspeed
  ;; setting wind speed influence on burn probability relative to wind direction
  if wind-speed = "none" [set wsv 1 set cws 1]
  if wind-speed = "light" [set wsv 2 set cws 2]
  if wind-speed = "medium" [set wsv 3 set cws 3]
  if wind-speed = "strong" [set wsv 4 set cws 4]

   if (wsv = 1)
      [set wd .7 set wd-1 .7 set wd-2 .7 set wd-3 .7 set wd-4 .7 set wd-5 .7 set wd-6 .7 set wd-7 .7 ]
   if (wsv = 2)
      [set wd .9 set wd-1 .8 set wd-2 .75 set wd-3 .7 set wd-4 .6 set wd-5 .7 set wd-6 .75 set wd-7 .8 ]
   if (wsv = 3 )
      [set wd 1.2 set wd-1 .9 set wd-2 .7 set wd-3 .6 set wd-4 .5 set wd-5 .6 set wd-6 .7 set wd-7 .9 set ember-fly-dist 3]
   if (wsv = 4)
      [set wd 1.4 set wd-1 1.1 set wd-2 .6 set wd-3 .3 set wd-4 .2 set wd-5 .4 set wd-6 .6 set wd-7 1.1 set ember-fly-dist 5 ]
end

to change-wind-speed
set windran random-float 1
let windchange  0
if (wsv = 1 and windchange = 0 and  cws = 1 and windran  < .1) [set windchange  1 set cws 2]
If (wsv = 1 and windchange = 0 and  cws = 2 and windran < .3) [set windchange  1 set cws 1]
If (wsv = 1 and windchange = 0 and  cws = 2 and windran >  .95) [set windchange  1 set cws 3]
If (wsv = 1 and windchange = 0 and  cws = 3 and windran < .7) [set windchange  1 set cws 2]

if (wsv = 2 and windchange = 0 and  cws = 1 and windran  < .6) [set windchange  1 set cws  2]
If (wsv = 2 and windchange = 0 and  cws = 2 and windran < .12) [set windchange  1 set cws  1]
If (wsv = 2 and windchange = 0 and  cws = 2 and windran >  .97) [set windchange  1 set cws  3]
If (wsv = 2 and windchange = 0 and  cws = 3 and windran < .8) [set windchange  1 set cws  2]
If (wsv = 2 and windchange = 0 and  cws = 3 and windran >  .99) [set windchange  1 set cws  4]
If (wsv = 2 and windchange = 0 and  cws = 4 and windran < .9) [set windchange  1 set cws  3]

if (wsv = 3 and windchange = 0 and  cws = 1 and windran  < .7) [set windchange  1 set cws  2]
If (wsv = 3 and windchange = 0 and  cws = 2 and windran < .1 and windran < 80) [set windchange  1 set cws  1]
If (wsv = 3 and windchange = 0 and  cws = 2 and windran >  .5)  [set windchange  1 set cws  3]
If (wsv = 3 and windchange = 0 and  cws = 3 and windran < .2)   [set windchange  1 set cws  2]
If (wsv = 3 and windchange = 0 and  cws = 3 and windran > .97 ) [set windchange  1 set cws  4]
If (wsv = 3 and windchange = 0 and  cws = 4 and windran < .98 ) [set windchange  1 set cws  3]

if (wsv = 4 and windchange = 0 and  cws = 1 and windran  < .8) [set windchange  1 set cws  2]
If (wsv = 4 and windchange = 0 and  cws = 2 and windran < .05 and windran < .7) [set windchange  1 set cws  1]
If (wsv = 4 and windchange = 0 and  cws = 2 and windran >  .5) [set windchange  1 set cws  3]
If (wsv = 4 and windchange = 0 and  cws = 3 and windran < .1 and windran < .8) [set windchange  1 set cws  2]
If (wsv = 4 and windchange = 0 and  cws = 3 and windran >  .8) [set windchange  1 set cws  4]
If (wsv = 4 and windchange = 0 and  cws = 4 and windran < .4) [set windchange  1 set cws  3]

   if (cws = 1)
      [set wd .7 set wd-1 .7 set wd-2 .7 set wd-3 .7 set wd-4 .7 set wd-5 .7 set wd-6 .7 set wd-7 .7 ]
   if (cws = 2)
      [set wd .9 set wd-1 .8 set wd-2 .75 set wd-3 .7 set wd-4 .6 set wd-5 .7 set wd-6 .75 set wd-7 .8 ]
   if (cws = 3 )
      [set wd 1.2 set wd-1 .9 set wd-2 .7 set wd-3 .6 set wd-4 .5 set wd-5 .6 set wd-6 .7 set wd-7 .9 set ember-fly-dist 3]
   if (cws = 4)
      [set wd 1.4 set wd-1 1.1 set wd-2 .6 set wd-3 .3 set wd-4 .2 set wd-5 .4 set wd-6 .6 set wd-7 1.1 set ember-fly-dist 8 ]

end

to calc-windinfluence
 if (wind-direction = "S")
  [ ask patch-at 0 1 [set wind wd]
   ask patch-at 1 1 [set wind wd-1]
   ask patch-at 1 0 [set wind wd-2]
   ask patch-at 1 -1 [set wind wd-3]
   ask patch-at 0 -1 [set wind wd-4]
   ask patch-at -1 -1 [set wind wd-5]
   ask patch-at -1 0 [set wind wd-6]
   ask patch-at -1 1 [set wind wd-7]
   set direction 0 ]
 if (wind-direction = "SW")
  [ ask patch-at 0 1 [set wind wd-7]
   ask patch-at 1 1 [set wind wd]
   ask patch-at 1 0 [set wind wd-1]
   ask patch-at 1 -1 [set wind wd-2]
   ask patch-at 0 -1 [set wind wd-3]
   ask patch-at -1 -1 [set wind wd-4]
   ask patch-at -1 0 [set wind wd-5]
   ask patch-at -1 1 [set wind wd-6]
   set direction 45]
 if (wind-direction = "W")
  [ ask patch-at 0 1 [set wind wd-6]
   ask patch-at 1 1 [set wind wd-7]
   ask patch-at 1 0 [set wind wd]
   ask patch-at 1 -1 [set wind wd-1]
   ask patch-at 0 -1 [set wind wd-2]
   ask patch-at -1 -1 [set wind wd-3]
   ask patch-at -1 0 [set wind wd-4]
   ask patch-at -1 1 [set wind wd-5]
   set direction 90]
 if (wind-direction = "NW")
  [ ask patch-at 0 1 [set wind wd-5]
   ask patch-at 1 1 [set wind wd-6]
   ask patch-at 1 0 [set wind wd-7]
   ask patch-at 1 -1 [set wind wd]
   ask patch-at 0 -1 [set wind wd-1]
   ask patch-at -1 -1 [set wind wd-2]
   ask patch-at -1 0 [set wind wd-3]
   ask patch-at -1 1 [set wind wd-4]
   set direction 135]
 if (wind-direction = "N")
  [ ask patch-at 0 1 [set wind wd-4]
   ask patch-at 1 1 [set wind wd-5]
   ask patch-at 1 0 [set wind wd-6]
   ask patch-at 1 -1 [set wind wd-7]
   ask patch-at 0 -1 [set wind wd]
   ask patch-at -1 -1 [set wind wd-1]
   ask patch-at -1 0 [set wind wd-2]
   ask patch-at -1 1 [set wind wd-3]
   set direction 180]
 if (wind-direction = "NE")
  [ ask patch-at 0 1 [set wind wd-3]
   ask patch-at 1 1 [set wind wd-4]
   ask patch-at 1 0 [set wind wd-5]
   ask patch-at 1 -1 [set wind wd-6]
   ask patch-at 0 -1 [set wind wd-7]
   ask patch-at -1 -1 [set wind wd]
   ask patch-at -1 0 [set wind wd-1]
   ask patch-at -1 1 [set wind wd-2]
   set direction 135]
 if (wind-direction = "E")
  [ ask patch-at 0 1 [set wind wd-2]
   ask patch-at 1 1 [set wind wd-3]
   ask patch-at 1 0 [set wind wd-4]
   ask patch-at 1 -1 [set wind wd-5]
   ask patch-at 0 -1 [set wind wd-6]
   ask patch-at -1 -1 [set wind wd-7]
   ask patch-at -1 0 [set wind wd]
   ask patch-at -1 1 [set wind wd-1]
   set direction 270]
 if (wind-direction = "SE")
  [ ask patch-at 0 1 [set wind wd-1]
   ask patch-at 1 1 [set wind wd-2]
   ask patch-at 1 0 [set wind wd-3]
   ask patch-at 1 -1 [set wind wd-4]
   ask patch-at 0 -1 [set wind wd-5]
   ask patch-at -1 -1 [set wind wd-6]
   ask patch-at -1 0 [set wind wd-7]
   ask patch-at -1 1 [set wind wd]
   set direction 315]
end

;***************************************************************************************
;***********************************VIEW DATA LAYERS**************************************
;***************************************************************************************


To view-new
;to choose base map layer visualisation
 if View = "Hill Shade" [import-pcolors-rgb "PNG/HS_DHM_greece.png"] ask patches [if (burnt < 100) [set pcolor black] ]
 if View = "Vegetation" [import-pcolors-rgb "PNG/LC_DHM.png" ]ask patches [if (burnt < 100) [set pcolor black] ]
 if view = "YSLB"  [import-pcolors-rgb "PNG/YSLB_DHM.png"] ask patches [if (burnt < 100) [set pcolor black] ]
 if View = "DEM" [import-pcolors-rgb "PNG/DEM_DHM.png"]ask patches [if (burnt < 100) [set pcolor black] ]
 if view = "Landsat"  [import-pcolors-rgb "PNG/SAT_DHM.png"]ask patches [if (burnt < 100) [set pcolor black] ]
 if view = "Wetness"  [import-pcolors-rgb "PNG/WET_DHM.png"]ask patches [if (burnt < 100) [set pcolor black] ]
end

to setup-patches
  import-pcolors-rgb "PNG/HS_DHM_greece.png"
  ask patches [set burnt burnt + 100]
  set dem-dataset gis:load-dataset "ASCII/DEM_Dhm.asc"
  set tslb-dataset gis:load-dataset "ASCII/YSLB_Dhm.asc"
  set veg-dataset gis:load-dataset "ASCII/Land_Cover2_Dhm.asc"
  set wetness-dataset gis:load-dataset "ASCII/WET_Dhm.asc"
  set burnt2015-dataset gis:load-dataset "ASCII/WET_Dhm.asc"
  gis:apply-raster dem-dataset elevation
  gis:apply-raster tslb-dataset  tslb
  gis:apply-raster veg-dataset veg
  gis:apply-raster wetness-dataset wetness
  gis:apply-raster burnt2015-dataset burnt2015
  gis:set-world-envelope      (gis:envelope-of tslb-dataset)
  ask patches [ ifelse (elevation <= 0) or (elevation >= 0) [] [set elevation 0]]
  ask patches [  ifelse (tslb <= 0) or (tslb >= 0)  [ ] [ set tslb 1 ]  ]
  ask patches [  ifelse (wetness <= 0) or (wetness >= 0)  [ ] [ set wetness 1 ]  ]
  ask patches [  ifelse (veg <= 0) or (veg >= 0)  [ ] [ set veg 1 ]  ]
 end


to save-ignition
  ask fires [ ask patch-here[set SAVED-IGNITION 1]]
end


;*********************************************************************************
;***********************************OUT_PUTS**************************************
;*********************************************************************************
to exp-ascii
   ;gis:set-world-envelope (list min-pxcor max-pxcor min-pycor max-pycor )
  ;let output-raster gis:create-raster world-width world-height gis:world-envelope
  let output-raster gis:patch-dataset totalout
  gis:store-dataset output-raster (word "/output/toutput" iteration ".asc")
  if iteration = 5 or iteration = 10 or iteration = 15 or iteration = 20 or iteration = 55 [ask patches [ set totalout 0] ]
end
to save-iter
  ask patches [if burnt < 100 [set burnt 1] ]
  ask patches [if burnt = 100 [set burnt 0]]
  if iteration = 1 [ask patches [ set totalout burnt]]
  if iteration > 1 [ask patches [ set out1 burnt set totalout (totalout + out1)]]
end


;;******************************* LABELS *********************************

to show-labels
  let mpx max-pxcor - 20
  let mpy min-pycor
  ask patch (mpx - 30) (mpy + 75) [set plabel "kmsq"]
  ask patch mpx (mpy + 75) [set plabel int burnt-area]
  ask patch (mpx - 20) (mpy + 45) [set plabel "day"]
  ask patch (mpx - 70) (mpy + 45) [set plabel timeod]
  ask patch mpx (mpy + 45) [set plabel 0]
  ask patch (mpx - 50) (mpy + 20) [set plabel wind-speed]
  ask patch (mpx - 0) (mpy + 20) [set plabel "wind"]
  ask patch (mpx - 130) (mpy + 20) [set plabel wind-direction]
  ask patch (mpx - 745) (mpy + 20) [set plabel "Fire danger"]
  ask patch (mpx - 725) (mpy + 20) [set plabel fire_danger]
end
to update-labels
  let mpx max-pxcor - 20
  let mpy min-pycor
  ask patch mpx (mpy + 75) [set plabel int burnt-area]
  ask patch (mpx - 70) (mpy + 45)  [set plabel timeod]
  ask patch mpx (mpy + 45) [set plabel int ((night / 2) + 1)]
;    ask patch (mpx - 725) (mpy + 20) [set plabel fire_danger]
end
@#$#@#$#@
GRAPHICS-WINDOW
176
12
1091
790
452
373
0.9912
1
22
1
1
1
0
0
0
1
-452
452
-373
373
1
1
1
ticks
20.0

BUTTON
20
35
114
69
Load map
setup\nshow-labels
NIL
1
T
OBSERVER
NIL
0
NIL
NIL
1

BUTTON
1091
57
1197
90
Drop Incendaries
ignite-forest
T
1
T
OBSERVER
NIL
1
NIL
NIL
1

BUTTON
1199
56
1254
89
NIL
go
T
1
T
OBSERVER
NIL
5
NIL
NIL
1

SLIDER
17
112
116
145
Fire_Danger
Fire_Danger
1
10
9
1
1
NIL
HORIZONTAL

CHOOSER
11
312
103
357
Wind-Direction
Wind-Direction
"N" "NE" "E" "SE" "S" "SW" "W" "NW"
1

CHOOSER
12
253
104
298
wind-speed
wind-speed
"none" "light" "medium" "strong"
3

SWITCH
1095
674
1214
707
variable-wind
variable-wind
0
1
-1000

BUTTON
1092
138
1182
172
Ignite Saved
clear\nset-ignition\nset-windspeed\nshow-labels
NIL
1
T
OBSERVER
NIL
4
NIL
NIL
1

TEXTBOX
16
154
145
266
Κίνδυνος Φωτιάς\n1-3 Χαμηλός\n3-4 Μέτριος\n5-6 Υψηλός\n7-8 Πολύ Υψηλός\n9-10 Εξαιρετικά Υψηλός
11
13.0
1

BUTTON
1092
98
1172
131
NIL
save-ignition
NIL
1
T
OBSERVER
NIL
2
NIL
NIL
1

BUTTON
1094
181
1158
215
reset
clear\nask patches [set saved-ignition 0]
NIL
1
T
OBSERVER
NIL
.
NIL
NIL
1

BUTTON
1097
269
1181
302
Vegetation
import-pcolors-rgb \"PNG/LC_DHM.png\"\nask patches [if (burnt < 100) [set pcolor black] ]\nset view \"Vegetation\"
NIL
1
T
OBSERVER
NIL
7
NIL
NIL
1

BUTTON
1097
305
1183
338
Year Last Burnt
import-pcolors-rgb \"PNG/YSLB_DHM.png\"\nask patches [if (burnt < 100) [set pcolor black] ]\nset view \"YSLB\"
NIL
1
T
OBSERVER
NIL
8
NIL
NIL
1

BUTTON
1097
340
1183
373
satellite
import-pcolors-rgb \"PNG/SAT_DHM.png\"\nask patches [if (burnt < 100) [set pcolor black]]\nset view \"Landsat\"
NIL
1
T
OBSERVER
NIL
9
NIL
NIL
1

BUTTON
1097
410
1185
443
Elevation
import-pcolors-rgb \"PNG/DEM_DHM.png\"\nask patches [if (burnt < 100) [set pcolor black]]\nset view \"DEM\"
NIL
1
T
OBSERVER
NIL
/
NIL
NIL
1

BUTTON
1097
374
1182
407
Wettness
import-pcolors-rgb \"PNG/WET_DHM.png\"\n ask patches [if (burnt < 100) [set pcolor black]]\n  set view \"Wettness\"
NIL
1
T
OBSERVER
NIL
6
NIL
NIL
1

TEXTBOX
1099
233
1202
265
ΠΡΟΒΟΛΗ ΧΑΡΤΩΝ
13
63.0
1

TEXTBOX
16
78
166
100
ΜΕΤΑΒΛΗΤΕΣ
18
0.0
1

TEXTBOX
1093
20
1243
42
Play
18
104.0
1

TEXTBOX
13
10
163
32
ΦΟΡΤΩΣΗ ΧΑΡΤΗ
17
14.0
1

TEXTBOX
20
614
170
656
ΠΡΟΣΘΕΤΕΣ\nΡΥΘΜΙΣΕΙΣ
12
0.0
1

BUTTON
1098
449
1183
482
Hill Shade
import-pcolors-rgb \"PNG/HS_DHM_greece.png\"\n  set view \"Hill Shade\"
NIL
1
T
OBSERVER
NIL
*
NIL
NIL
1

TEXTBOX
12
367
172
457
Κατεύθυνση Ανέμου\nNW: ΒΔ\nE-SE: Α-ΝΑ\nS-SE: Β-ΒΑ\nSE-NE: ΝΑ-ΒΑ\nN-NW: Β-ΒΔ
11
0.0
1

BUTTON
1097
487
1184
520
Fire freqency
import-pcolors-rgb \"PNG/FF_DHM.png\"\n  set view \"Fire Freq\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1097
530
1187
564
Burnability
ask patches [ set pcolor scale-color blue fuelload 0 2\n ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1093
635
1205
669
Change Wind speed
set-windspeed
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
10
501
103
546
set-time
set-time
"morning" "noon" "afternoon" "evening"
0

BUTTON
1186
138
1242
171
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
1096
712
1202
745
just-wind
just-wind
1
1
-1000

TEXTBOX
1094
602
1244
620
ΕΠΙΛΟΓΕΣ ΑΝΕΜΟΥ\n
12
0.0
1

BUTTON
18
553
81
586
Set
set-time-of-day\nset-windspeed\nshow-labels
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
8
658
118
691
time-of-day
time-of-day
0
1
-1000

SLIDER
11
463
138
496
number-of-airplanes
number-of-airplanes
0
20
5
1
1
NIL
HORIZONTAL

SWITCH
0
705
146
738
show_messages
show_messages
0
1
-1000

BUTTON
10
740
133
773
setup_airlanes and sensors
setup1
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1301
283
1411
328
Κατάσταση Αφών
[status] of one-of airplanes
17
1
11

MONITOR
1287
81
1416
126
Κατάσταση Sensor 0
[status] of sensor  0
17
1
11

TEXTBOX
1271
58
1421
76
Κατάσταση Αφων-Sensors
12
104.0
1

MONITOR
1285
134
1414
179
Κατάσταση Sensor 1
[status] of sensor 1
17
1
11

MONITOR
1289
184
1406
229
Έλεγχος state 0
[state] of sensor 0
17
1
11

MONITOR
1291
236
1408
281
Έλεγχος state 1
[state] of sensor 1
17
1
11

BUTTON
1300
330
1400
363
show_range
ask sensors [ask patches in-radius  150 WITH \n[ DISTANCE MYSELF > 149 ] \n[set pcolor 125]\n]\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1294
372
1421
417
Ποσότητα νερου Α/φων
[water]  of one-of airplanes
17
1
11

SLIDER
1274
425
1446
458
initial-water
initial-water
0
400
201
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This model is a work in progress for a north Australian landscape fire simulation game. The primary idea is to show how a range of variables effect fire spread when conducting aerial incendiary management burns early in the dry season and how these fuel reduction fires effect the spread of late season wild fires.


## HOW IT WORKS

The model currently uses the following variable to determine if a pixel will ignite:

- a grass vegetation map derved from Landsat Satellite imagery and a time since burnt layer (from NAFI) to produce a fuel load variable.  The  vegetation layer shows grass, low cover and mangrove types.

- an elevation layer (SRTM-DEM) is used to determine slope in relation to fire spread direction.

- a topographic wetness layer, derived from the DEM, is used to represent differntial landscape curing.

- Fire danger as an value from 1 (wet season) to 10 (late dry season). This combines the influence of curing and temperature on fire spread.

- Wind speed from none (no wind influence) to strong. Wind speed increses the directionality and likelyhood of a pixel ignighting.

- wind direction (the direction a fire will spread)


## HOW TO USE IT

Click the drop incendaries button and use the cursor to ignite some initial pixels. Change curing, wind direction and wind speed to set your fire senario. Use the variable-wind button to allow the model to  randomly change the wind speed as the model runs. Use the view drop list to display a one of a range of landscape layers.


## THINGS TO NOTICE

Fires should not run down slope as well as up slope.
Fire do not burn will on recently burnt hummock grasslands.

## THINGS TO TRY

Try running the model to set fire breaks early in the in the dry season (fire danger 6-7) then run the model with some single ignition points late in the dry (curing 9-10). Are you able to prevent fires spreading through your early season burns.

Try runing the model with some of the different landscape layers displayed.

Try running it projected over a sandpit sculpted with refernece to the elevation layer.

## EXTENDING THE MODEL

- Variable fire spread speed
- Burn severity
- An estimate of chopper time/cost
- An estimate of burn cost to burn area and fire severity as a measure of management     burn effectiveness.


## RELATED MODELS

Based on the fire break model.

## CREDITS AND REFERENCES

This model was produced in May 2017, More information about the model can be found at: https://rohanfisher.wordpress.com/incendiary-a-fire-spread-modelling-tool/

Copyright 2017 Rohan Fisher.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

alarm
false
10
Circle -13345367 true true 105 80 90
Rectangle -13345367 true true 90 255 210 300
Line -16777216 false 75 255 225 255
Polygon -13345367 true true 90 255 120 150 180 150 210 255
Rectangle -7500403 true false 105 165 195 150

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Export multiple  burns as pictures" repetitions="1" runMetricsEveryStep="true">
    <setup>clear
set-ignition
set iteration iteration + 1
show-labels</setup>
    <go>go</go>
    <final>save-iter
export-view (word "Output/" iteration ".png")</final>
    <exitCondition>count turtles &lt; 1</exitCondition>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="Wind-Speed">
      <value value="&quot;light&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Wind-Direction">
      <value value="&quot;SE&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-of-day">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="set-time">
      <value value="&quot;noon&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="variable-wind">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Fire_Danger">
      <value value="5"/>
      <value value="6"/>
      <value value="7"/>
      <value value="8"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Export multiple  burns as pictures - multi variable" repetitions="3" runMetricsEveryStep="true">
    <setup>clear
set-ignition
set iteration iteration + 1</setup>
    <go>go</go>
    <final>save-iter
export-view (word "Output/" iteration ".png")</final>
    <exitCondition>count turtles &lt; 1</exitCondition>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="Wind-Speed">
      <value value="&quot;light&quot;"/>
      <value value="&quot;medium&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Wind-Direction">
      <value value="&quot;E&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-of-day">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="variable-wind">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Fire_Danger">
      <value value="7"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
