import webview from '@ohos.web.webview';

@Component
export struct CampusPage {
  private controller: webview.WebviewController = new webview.WebviewController();
  build() {
    Column() {
      Row() { Text('校园').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#555555'); Text('SCHOOL').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#777777').margin({ left: 12 }); }.width('100%').padding({ left: 28, top: 32, bottom: 26 });
      Web({ src: 'https://news.wustlinghang.cn', controller: this.controller }).width('100%').layoutWeight(1).javaScriptAccess(true).domStorageAccess(true);
    }.width('100%').height('100%').backgroundColor('#F5F6F7');
  }
}
