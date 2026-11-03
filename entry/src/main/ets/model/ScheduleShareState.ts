export interface ScheduleShareInvite {
  token: string;
  expiresAt: number;
  expiresIn: number;
}

export interface ScheduleShareState {
  isDynamic: boolean;
  allowExtra: boolean;
  semester: string;
  loading: boolean;
  qrValue: string;
  expiresIn: number;
  errorMsg: string;
}

export function initialScheduleShareState(): ScheduleShareState {
  return {
    isDynamic: true,
    allowExtra: false,
    semester: '',
    loading: false,
    qrValue: '',
    expiresIn: 0,
    errorMsg: ''
  };
}

export class ScheduleShareController {
  state: ScheduleShareState = initialScheduleShareState();
  onChange: (state: ScheduleShareState) => void = () => {};
  private createInvite: (semester: string, allowExtra: boolean) => Promise<ScheduleShareInvite>;
  private requestId: number = 0;
  private active: boolean = false;
  private nickname: string = '';
  private deadline: number = 0;

  constructor(createInvite: (semester: string, allowExtra: boolean) => Promise<ScheduleShareInvite>) {
    this.createInvite = createInvite;
  }

  async initialize(nickname: string, semester: string): Promise<void> {
    this.active = true;
    this.nickname = nickname;
    this.state.semester = semester.trim();
    await this.refresh();
  }

  async setDynamic(value: boolean): Promise<void> {
    this.state.isDynamic = value;
    await this.refresh();
  }

  async setAllowExtra(value: boolean): Promise<void> {
    if (this.state.allowExtra === value) return;
    this.state.allowExtra = value;
    if (this.state.isDynamic) {
      await this.refresh();
    } else {
      this.publish();
    }
  }

  async refresh(): Promise<void> {
    if (!this.active) return;
    const requestId: number = ++this.requestId;
    this.deadline = 0;
    this.state.qrValue = '';
    this.state.expiresIn = 0;
    this.state.errorMsg = '';
    this.state.loading = false;
    if (!this.state.semester || this.state.semester.length > 32) {
      this.state.errorMsg = '请先在课表页面选择有效学期';
      this.publish();
      return;
    }
    if (!this.state.isDynamic) {
      const value: string = `wusthelper://schedule?student=${encodeURIComponent(this.nickname)}&semester=${encodeURIComponent(this.state.semester)}`;
      this.state.qrValue = value.length <= 512 ? value : '';
      this.state.errorMsg = value.length <= 512 ? '' : '分享信息过长，无法生成二维码';
      this.publish();
      return;
    }
    this.state.loading = true;
    this.publish();
    const requestedAt: number = Date.now();
    try {
      const invite: ScheduleShareInvite = await this.createInvite(this.state.semester, this.state.allowExtra);
      if (!this.active || requestId !== this.requestId) return;
      if (!/^[a-f0-9]{64}$/.test(invite.token) || !Number.isFinite(invite.expiresAt) ||
        !Number.isFinite(invite.expiresIn) || invite.expiresIn <= 0) {
        throw new Error('动态课表凭证无效，请重试');
      }
      this.deadline = Math.min(invite.expiresAt, requestedAt + Math.min(300, invite.expiresIn) * 1000);
      this.state.expiresIn = Math.max(0, Math.ceil((this.deadline - Date.now()) / 1000));
      if (this.state.expiresIn === 0) throw new Error('二维码已过期，请刷新');
      this.state.qrValue = `wusthelper://dynamic-schedule?token=${encodeURIComponent(invite.token)}`;
    } catch (error) {
      if (!this.active || requestId !== this.requestId) return;
      this.deadline = 0;
      this.state.qrValue = '';
      this.state.expiresIn = 0;
      this.state.errorMsg = error instanceof Error ? error.message : '动态二维码生成失败，请重试';
    } finally {
      if (this.active && requestId === this.requestId) {
        this.state.loading = false;
        this.publish();
      }
    }
  }

  tick(now: number = Date.now()): void {
    if (!this.active || !this.state.isDynamic || this.deadline <= 0) return;
    const remaining: number = Math.max(0, Math.ceil((this.deadline - now) / 1000));
    if (remaining === this.state.expiresIn) return;
    this.state.expiresIn = remaining;
    if (remaining === 0) {
      this.deadline = 0;
      this.state.qrValue = '';
      this.state.errorMsg = '二维码已过期，请刷新';
    }
    this.publish();
  }

  dispose(): void {
    this.active = false;
    ++this.requestId;
    this.deadline = 0;
    this.state.loading = false;
    this.state.qrValue = '';
    this.state.expiresIn = 0;
  }

  private publish(): void {
    this.onChange({
      isDynamic: this.state.isDynamic,
      allowExtra: this.state.allowExtra,
      semester: this.state.semester,
      loading: this.state.loading,
      qrValue: this.state.qrValue,
      expiresIn: this.state.expiresIn,
      errorMsg: this.state.errorMsg
    });
  }
}
