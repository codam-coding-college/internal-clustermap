
/* 
* This function gets the viewport size in a more reliable way (especially for firefox)
*/
function viewportSize() {
    var test = document.createElement("div");

    test.style.cssText = "position: fixed;top: 0;left: 0;bottom: 0;right: 0;";
    document.documentElement.insertBefore(test, document.documentElement.firstChild);

    var dims = { width: test.offsetWidth, height: test.offsetHeight };
    document.documentElement.removeChild(test);

    return dims;
}

/*
* According to the internet this is how you check if the browser is firefox
*/
var isFirefox = typeof InstallTrigger !== 'undefined';
var viewinfo = viewportSize();
viewinfo.isFirefox = isFirefox;

/*
* Viewinfo now contains width, height and isFirefox. Elm will use these to display the correct mapsize.
*/
var app = Elm.Main.init({
    node: document.querySelector('main'),
    flags: viewinfo
})
