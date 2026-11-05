import { promptAction, router } from '@kit.ArkUI';
import { PasswordRecoveryApi, RecoveryCaptcha, RecoveryIdentity } from '../../net/PasswordRecoveryApi';
import { AppStorage as PreferencesStorage } from '../../store/AppStorage';

@Entry
@Component
struct PasswordRecoveryPage {
  @State private studentId: string = '';
  @State private realName: string = '';
  @State private idCard: string = '';
  @State private captchaCode: string = '';
  @State private captchaImage: string = '';
  @State private phone: string = '';
  @State private smsCode: string = '';
  @State private newPassword: string = '';
  @State private confirmPassword: string = '';
  @State private stage: number = 0;
  @State private busy: boolean = false;
  @State private cooldown: number = 0;
  @State private resultMessage: string = '';
  @State private resultNeedsLogin: boolean = false;
  private recoveryId: string = '';
  private cooldownUntil: number = 0;
  private countdownTimer: number = -1;

  aboutToAppear(): void {
    this.prefillStudentId();
    this.loadCaptcha();
  }

  aboutToDisappear(): void {
    this.stopCountdown();
    this.recoveryId = '';
    this.idCard = '';
    this.smsCode = '';
    this.newPassword = '';
    this.confirmPassword = '';
  }

  onBackPress(): boolean { return this.busy; }

  private async prefillStudentId(): Promise<void> {
    const storage = PreferencesStorage.getInstance();
    const saved = await storage.getStudentId();
    if (!this.studentId && !(await storage.getIsGraduate())) this.studentId = saved;
  }

  private showError(error: Error, fallback: string): void {
    promptAction.showToast({ message: error.message || fallback, duration: 2400 });
  }

  private imageUri(value: string): string {
    const raw = value.trim();
    if (raw.startsWith('data:image/')) return raw;
    let format: string = 'png';
    if (raw.startsWith('/9j/')) format = 'jpeg';
    else if (raw.startsWith('R0lGOD')) format = 'gif';
    else if (raw.startsWith('Qk')) format = 'bmp';
    return `data:image/${format};base64,${raw}`;
  }

  private async loadCaptcha(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    this.stage = 0;
    this.recoveryId = '';
    this.captchaImage = '';
    this.captchaCode = '';
    this.smsCode = '';
    this.newPassword = '';
    this.confirmPassword = '';
    this.phone = '';
    this.stopCountdown();
    try {
      const data: RecoveryCaptcha = await PasswordRecoveryApi.captcha();
      this.recoveryId = data.recovery_id || '';
      this.captchaImage = this.imageUri(data.image_base64 || '');
    } catch (error) {
      this.showError(error as Error, '图形验证码加载失败');
    } finally { this.busy = false; }
  }

  private async verifyIdentity(): Promise<void> {
    if (this.busy) return;
    if (!this.recoveryId || !this.captchaImage) {
      promptAction.showToast({ message: '请先获取图形验证码', duration: 2000 });
      return;
    }
    if (!this.studentId.trim() || !this.realName.trim() || !this.idCard.trim() || !this.captchaCode.trim()) {
      promptAction.showToast({ message: '请填写学号、姓名、身份证号和图形验证码', duration: 2000 });
      return;
    }
    this.busy = true;
    try {
      const data: RecoveryIdentity = await PasswordRecoveryApi.identity(this.recoveryId, this.studentId.trim(),
        this.realName.trim(), this.idCard.trim(), this.captchaCode.trim());
      this.studentId = data.account || this.studentId.trim();
      this.phone = data.masked_phone || '';
      this.idCard = '';
      this.captchaCode = '';
      this.captchaImage = '';
      this.stage = 1;
    } catch (error) {
      this.showError(error as Error, '身份验证失败');
    } finally { this.busy = false; }
  }

  private stopCountdown(): void {
    if (this.countdownTimer >= 0) clearInterval(this.countdownTimer);
    this.countdownTimer = -1;
    this.cooldown = 0;
    this.cooldownUntil = 0;
  }

  private startCountdown(seconds: number): void {
    this.stopCountdown();
    this.cooldownUntil = Date.now() + Math.max(1, seconds) * 1000;
    this.cooldown = Math.ceil((this.cooldownUntil - Date.now()) / 1000);
    this.countdownTimer = setInterval(() => {
      this.cooldown = Math.max(0, Math.ceil((this.cooldownUntil - Date.now()) / 1000));
      if (this.cooldown === 0) this.stopCountdown();
    }, 1000);
  }

  private async sendSms(): Promise<void> {
    if (this.busy || this.cooldown > 0 || !this.recoveryId) return;
    this.busy = true;
    try {
      const seconds = await PasswordRecoveryApi.sendCode(this.recoveryId);
      this.startCountdown(seconds);
      promptAction.showToast({ message: '验证码已发送', duration: 1800 });
    } catch (error) {
      // The server reserves its cooldown before contacting the school, including on timeout.
      this.startCountdown(60);
      this.showError(error as Error, '短信发送失败');
    } finally { this.busy = false; }
  }

  private async verifySms(): Promise<void> {
    if (this.busy) return;
    if (!this.smsCode.trim()) {
      promptAction.showToast({ message: '请输入短信验证码', duration: 1800 });
      return;
    }
    this.busy = true;
    try {
      await PasswordRecoveryApi.verify(this.recoveryId, this.smsCode.trim());
      this.smsCode = '';
      this.stopCountdown();
      this.stage = 2;
    } catch (error) {
      this.showError(error as Error, '短信验证码验证失败');
    } finally { this.busy = false; }
  }

  private async clearMatchingSavedPassword(): Promise<boolean> {
    const storage = PreferencesStorage.getInstance();
    const savedStudentId = await storage.getStudentId();
    if (savedStudentId.trim() !== this.studentId.trim() || await storage.getIsGraduate()) return false;
    // Stop automatic relogin with the old password before the school changes it.
    await storage.setPassword('');
    await storage.setToken('');
    await storage.setIsLogin(false);
    return true;
  }

  private async submitPassword(): Promise<void> {
    if (this.busy) return;
    if (!this.newPassword || this.newPassword !== this.newPassword.trim()) {
      promptAction.showToast({ message: '请输入新密码，首尾不能有空格', duration: 2000 });
      return;
    }
    if (this.newPassword !== this.confirmPassword) {
      promptAction.showToast({ message: '两次输入的密码不一致', duration: 2000 });
      return;
    }
    this.busy = true;
    try {
      this.resultNeedsLogin = await this.clearMatchingSavedPassword();
    } catch {
      this.busy = false;
      promptAction.showToast({ message: '无法清除本机旧密码，请稍后重试', duration: 2400 });
      return;
    }
    try {
      await PasswordRecoveryApi.reset(this.recoveryId, this.newPassword);
      this.resultMessage = '密码修改成功，请使用新密码重新登录教务系统。';
    } catch {
      // The server may have processed the request before a timeout or other failure.
      // Do not submit it again automatically, and do not claim that it failed.
      this.resultMessage = '本次提交的结果无法确认。请先尝试用新密码登录，确认后再决定是否重新操作。';
    } finally {
      this.recoveryId = '';
      this.newPassword = '';
      this.confirmPassword = '';
      this.stage = 3;
      this.busy = false;
    }
  }

  @Builder
  private field(label: string, value: string, change: (value: string) => void, password: boolean = false) {
    Column() {
      Text(label).fontSize(15).fontColor('#444444').width('100%').margin({ bottom: 6 })
      TextInput({ text: value, placeholder: `请输入${label}` }).width('100%').height(48)
        .type(password ? InputType.Password : InputType.Normal).enableAutoFill(false)
        .backgroundColor('#F5F6F8').borderRadius(8).enabled(!this.busy).onChange(change)
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 14 })
  }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(26).fontColor('#333333').onClick(() => { if (!this.busy) router.back(); })
        Text('修改教务密码').fontSize(22).fontWeight(FontWeight.Bold).margin({ left: 16 })
      }.width('100%').height(58).padding({ left: 16, right: 16 }).backgroundColor(Color.White)
      Scroll() {
        Column() {
          if (this.stage === 0) {
            Text('本科生教务密码重置').fontSize(20).fontWeight(FontWeight.Bold).width('100%')
            Text('通过学校身份核验和绑定手机验证，设置新的教务登录密码。研究生暂不支持。')
              .fontSize(14).fontColor('#777777').lineHeight(21).width('100%').margin({ top: 8 })
            this.field('学号', this.studentId, (value: string) => { this.studentId = value; })
            this.field('姓名', this.realName, (value: string) => { this.realName = value; })
            this.field('身份证号', this.idCard, (value: string) => { this.idCard = value; })
            Row() {
              TextInput({ text: this.captchaCode, placeholder: '图形验证码' }).layoutWeight(1).height(48)
                .enabled(!this.busy).enableAutoFill(false).onChange((value: string) => { this.captchaCode = value; })
              if (this.captchaImage) {
                Image(this.captchaImage).width(120).height(48).objectFit(ImageFit.Contain).margin({ left: 8 })
                  .onClick(() => this.loadCaptcha())
              } else {
                Text(this.busy ? '加载中…' : '获取验证码').fontSize(14).fontColor('#20C894').margin({ left: 8 })
                  .onClick(() => this.loadCaptcha())
              }
            }.width('100%').margin({ top: 16 })
            Text('点击图片可更换验证码').fontSize(13).fontColor('#999999').width('100%').margin({ top: 6 })
            Button(this.busy ? '请稍候…' : '验证身份').width('100%').height(48).margin({ top: 24 })
              .backgroundColor('#20C894').enabled(!this.busy).onClick(() => this.verifyIdentity())
          } else if (this.stage === 1) {
            Text('验证绑定手机').fontSize(20).fontWeight(FontWeight.Bold).width('100%')
            Text(`验证码将发送到${this.phone || '学校绑定的手机号'}`).fontSize(14).fontColor('#777777')
              .width('100%').margin({ top: 12 })
            this.field('短信验证码', this.smsCode, (value: string) => { this.smsCode = value; })
            Button(this.cooldown > 0 ? `${this.cooldown} 秒后重新发送` : '发送短信验证码')
              .width('100%').height(46).margin({ top: 20 }).backgroundColor('#E6F8F1').fontColor('#168F66')
              .enabled(!this.busy && this.cooldown === 0).onClick(() => this.sendSms())
            Button(this.busy ? '请稍候…' : '验证短信').width('100%').height(48).margin({ top: 12 })
              .backgroundColor('#20C894').enabled(!this.busy).onClick(() => this.verifySms())
            Text('无法接收短信？请联系学校处理绑定手机问题。').fontSize(13).fontColor('#777777')
              .width('100%').margin({ top: 16 })
            Text('重新开始').fontSize(14).fontColor('#168F66').margin({ top: 20 })
              .onClick(() => this.loadCaptcha())
          } else if (this.stage === 2) {
            Text('设置新密码').fontSize(20).fontWeight(FontWeight.Bold).width('100%')
            Text('请按学校的密码要求设置。提交后需要使用新密码重新登录。')
              .fontSize(14).fontColor('#777777').width('100%').margin({ top: 12 })
            this.field('新密码', this.newPassword, (value: string) => { this.newPassword = value; }, true)
            this.field('确认新密码', this.confirmPassword, (value: string) => { this.confirmPassword = value; }, true)
            Button(this.busy ? '提交中…' : '确认修改').width('100%').height(48).margin({ top: 24 })
              .backgroundColor('#20C894').enabled(!this.busy).onClick(() => this.submitPassword())
            Text('重新开始').fontSize(14).fontColor('#168F66').margin({ top: 20 })
              .onClick(() => this.loadCaptcha())
          } else {
            Text('操作结束').fontSize(20).fontWeight(FontWeight.Bold).width('100%')
            Text(this.resultMessage).fontSize(16).fontColor('#555555').lineHeight(24).width('100%').margin({ top: 16 })
            if (this.resultNeedsLogin) {
              Button('去登录').width('100%').height(48).margin({ top: 24 }).backgroundColor('#20C894')
                .onClick(() => router.replaceUrl({ url: 'pages/login/LoginPage' }))
            } else {
              Button('返回').width('100%').height(48).margin({ top: 24 }).backgroundColor('#20C894')
                .onClick(() => router.back())
            }
          }
        }.width('100%').padding(20).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor(Color.White)
  }
}
