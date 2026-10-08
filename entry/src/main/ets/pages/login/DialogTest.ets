/**
 * DialogTest.ets — 验证 @CustomDialog 语法
 * 不参与业务逻辑，仅用于测试编译
 */
import { promptAction } from '@kit.ArkUI';
import { CustomDialogOptions, createDialogController } from '../../utils/CustomDialogOptions';

// ════════════════ 测试 Dialog A：controller 有默认值，builder 直接调用（无 new、无箭头函数）════════════════

@CustomDialog
struct TestDialogA {
  controller: CustomDialogController = createDialogController({ builder: () => {} });
  message: string = '';

  build() {
    Column() {
      Text(this.message).fontSize(14).fontColor('#333')
    }.padding(20)
  }
}

// ════════════════ 测试 Dialog B：controller 有默认值，builder 用箭头函数调用（无 new）════════════════

@CustomDialog
struct TestDialogB {
  controller: CustomDialogController = createDialogController({ builder: () => {} });
  message: string = '';

  build() {
    Column() {
      Text(this.message).fontSize(14).fontColor('#333')
    }.padding(20)
  }
}

// ════════════════ 测试 Dialog C：controller 有默认值，builder 用箭头函数调用 new════════════════

@CustomDialog
struct TestDialogC {
  controller: CustomDialogController = createDialogController({ builder: () => {} });
  message: string = '';

  build() {
    Column() {
      Text(this.message).fontSize(14).fontColor('#333')
    }.padding(20)
  }
}

// ════════════════ 主页面：分别用三种语法创建控制器 ════════════════

@Entry
@Component
struct DialogTest {
  // 语法 A：builder 直接赋值 Dialog()，无 new，无箭头函数
  ctrlA: CustomDialogController = createDialogController({
    builder: () => {
      TestDialogA({ message: '语法A: 直接调用, 无new, 无箭头函数' });
    },
  });

  // 语法 B：builder 用箭头函数，内部无 new
  ctrlB?: CustomDialogController;

  // 语法 C：builder 用箭头函数，内部加 new
  ctrlC?: CustomDialogController;

  aboutToAppear(): void {
    this.ctrlB = createDialogController({
      builder: () => {
        TestDialogB({ message: '语法B: 箭头函数, 无new' });
      },
    });

    this.ctrlC = createDialogController({
      builder: () => {
        new TestDialogC({ message: '语法C: 箭头函数, new' });
      },
    });
  }

  build() {
    Column() {
      Text('Dialog 语法测试').fontSize(20).fontWeight(FontWeight.Bold).margin(20)

      Button('打开 语法A').width('80%').margin(8).onClick(() => { this.ctrlA.open(); })
      Button('打开 语法B').width('80%').margin(8).onClick(() => { this.ctrlB?.open(); })
      Button('打开 语法C').width('80%').margin(8).onClick(() => { this.ctrlC?.open(); })
    }.width('100%').height('100%').padding(20)
  }
}
