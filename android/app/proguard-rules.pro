# i metodi chiamati dalle pagine (window.GenioApp) devono restare con il loro nome
-keepclassmembers class app.genio.tablet.Ponte {
    @android.webkit.JavascriptInterface <methods>;
}
