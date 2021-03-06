# 15mar17abu
# (c) Software Lab. Alexander Burger

(setq *Uuid (in "UUID" (line T)))

(symbols 'android 'pico)

(for F '("JAVA" "LISP" "RQST" "RPLY")
   (native "@" "mkfifo" 'I F `(oct "600")) )

(for D (dir ".pil/tmp/")
   (call "rm" "-rf" (pack ".pil/tmp/" D)) )

# SSL
(sys "LD_LIBRARY_PATH" "lib")
(sys "SSL_CERT_FILE" "tls/cert.pem")

# Android Context
(local) CONTEXT
(de CONTEXT . {OOOO40000000000})

# Java I/O
# (java "cls" 'T ['any ..]) -> obj       New object
# (java 'obj 'msg ['any ..]) -> any      Send message to object
# (java 'obj "fld" ["fld" ..]) -> any    Value of object field
# (java "cls" 'msg ['any ..]) -> any     Call method in class
# (java "cls" "fld" ["fld" ..]) -> any   Value of class field
# (java T "cls" ["cls" ..]) -> obj       Define interface
# (java 'obj) -> [lst ..]                Reflect object
# (java "cls") -> [lst lst ..]           Reflect class
(local) [java *Java *Lisp]
(de java @
   (unless *Java
      (setq *Java (open "JAVA")  *Lisp (open "LISP"))
      (task (open "RQST")  R (open "RPLY")
         (in @
            (out R
               (ext 65535
                  (symbols '(android pico)
                     (pr
                        (with (rd)  # Obj
                           (if (get (rd) This)
                              (apply @ (rd))
                              (rd)
                              NIL ) ) ) ) ) ) ) )
      (forked)
      (queue '*Ext (cons 65535 java))
      (con java (cddr java)) )
   (ext 65535
      (symbols '(android pico)
         (out *Java (pr (rest)))
         (let? Val (in *Lisp (rd))
            (if (== 'err (car (pair Val)))
               (nil (msg (cdr Val)))
               Val ) ) ) ) )

# Android device ID
(local) [dev getString getContentResolver]
(de dev ()
   (java "android.provider.Settings$Secure" 'getString
      (java CONTEXT 'getContentResolver)
      "android_id" ) )

# Push-Load
(local) loadUrl
(de loadUrl @
   (java CONTEXT 'loadUrl (pass pack)) )

# Wake lock
(local) [wake getSystemService newWakeLock]
(de wake (Flg)
   (java
      (java
         (java CONTEXT 'getSystemService "power")  # PowerManager
         'newWakeLock 1 "PilWake" )                # New WakeLock
      (if Flg 'acquire 'release) ) )

# Notification
(local) [
   notify setSmallIcon setContentTitle setContentText setAutoCancel setLights
   getSystemService build ]
(de notify (Ttl Msg Id)
   (let B (java "android.support.v4.app.NotificationCompat$Builder" T CONTEXT)
      (java B 'setSmallIcon (java "de.software_lab.pilbox.R$drawable" "notify"))
      (java B 'setContentTitle Ttl)
      (java B 'setContentText Msg)
      (java B 'setAutoCancel T)
      (java B 'setLights `(hex "FFFFFF") 500 500)
      (java (java CONTEXT 'getSystemService "notification")  # NotificationManager
         'notify (or Id 0) (java B 'build) ) ) )

# Generate file content URI
(local) [fileUri getUriForFile getPackageName]
(de fileUri (File)
   (out File)
   (java "android.support.v4.content.FileProvider" 'getUriForFile
      CONTEXT
      (pack (java CONTEXT 'getPackageName) ".fileprovider")
      (java "java.io.File" T File) ) )

# Start Activity for a result
(local) [
   startActivityForResult *ResultProxy *ProxyResults resolveActivity
   getPackageManager putExtra setResultProxy good bad ]
(de startActivityForResult (Fun Action . @)
   (let Intent (java "android.content.Intent" T Action)
      (when (java Intent 'resolveActivity (java CONTEXT 'getPackageManager))
         (while (args)
            (let S (next)
               (if (str? S)
                  (java Intent 'putExtra S (next))
                  (java Intent S (next) (next)) ) ) )
         (unless *ResultProxy
            (java CONTEXT 'setResultProxy
               (setq *ResultProxy (java T "de.software_lab.pilbox.ResultProxy")) ) )
         (def 'good *ResultProxy
            '((Req Intent)
               (when (asoq Req *ProxyResults)
                  (del @ '*ProxyResults)
                  ((cdr @) Intent) ) ) )
         (def 'bad *ResultProxy
            '((Req Res)
               (del (asoq Req *ProxyResults) '*ProxyResults) ) )
         (let Req (inc (0))
            (push '*ProxyResults (cons Req Fun))
            (java (; CONTEXT GUI) 'startActivityForResult Intent Req) ) ) ) )

# GPS access
(local) [
   gps *LocMan *LocLsn onLocationChanged onProviderDisabled onProviderEnabled
   onStatusChanged requestLocationUpdates isProviderEnabled getLastKnownLocation
   getLatitude getLongitude ]
(de gps ()
   (unless *LocMan
      (setq
         *LocMan (java CONTEXT 'getSystemService "location")
         *LocLsn (java T "android.location.LocationListener") )
      (def 'onLocationChanged *LocLsn
         '((Loc)
            (msg Loc " onLocationChanged")
            NIL ) )
      (def 'onProviderDisabled *LocLsn
         '((Prov)) )
      (def 'onProviderEnabled *LocLsn
         '((Prov)) )
      (def 'onStatusChanged *LocLsn
         '((Prov Stat Extras)) )
      (java *LocMan 'requestLocationUpdates "gps" '(L . 20000) (-3 . 100) *LocLsn) )
   (when (java *LocMan 'isProviderEnabled "gps")
      (let? Loc (java *LocMan 'getLastKnownLocation "gps")
         (cons
            (+ (java Loc 'getLatitude) 90000000)
            (+ (java Loc 'getLongitude) 180000000) ) ) ) )

# Camera access
(local) [hasCamera hasSystemFeature]
(de hasCamera ()
   (java (java CONTEXT 'getPackageManager)  # PackageManager
      'hasSystemFeature "android.hardware.camera" ) )

## '((Intent)
##    (setq *Picture (tmp "img"))
##    (loadUrl (baseHRef) *SesId "app/camera.l") )
(local) takePicture
(de takePicture (Dst Fun)
   (startActivityForResult Fun
      "android.media.action.IMAGE_CAPTURE"
      "output" (fileUri Dst) ) )

# ZXing QR-Codes
## '((Intent)
##    (java Intent 'getStringExtra "SCAN_RESULT")
##    (java Intent 'getStringExtra "SCAN_RESULT_FORMAT") )
(local) scanQR
(de scanQR (Fun)
   (startActivityForResult Fun
      "com.google.zxing.client.android.SCAN"
      "SCAN_MODE" "QR_CODE_MODE" ) )

# vi:et:ts=3:sw=3
