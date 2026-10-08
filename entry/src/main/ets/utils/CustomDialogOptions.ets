export interface DialogOffset {
  dx: number | string;
  dy: number | string;
}

export interface CustomDialogOptions {
  builder: () => void;
  autoCancel?: boolean;
  customStyle?: boolean;
  maskColor?: string | Resource;
  alignment?: DialogAlignment;
  offset?: DialogOffset;
}

export function createDialogController(options: CustomDialogOptions): CustomDialogController {
  return new CustomDialogController(options);
}
