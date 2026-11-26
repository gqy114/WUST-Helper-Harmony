export interface CropRectangle {
  x: number;
  y: number;
  width: number;
  height: number;
}

export function coverScale(imageWidth: number, imageHeight: number, width: number, height: number): number {
  return Math.max(width / imageWidth, height / imageHeight);
}

export function cropOffset(offset: number, scaledSize: number, viewportSize: number): number {
  const limit = Math.max(0, (scaledSize - viewportSize) / 2);
  return Math.min(limit, Math.max(-limit, offset));
}

export function sourceCrop(imageWidth: number, imageHeight: number, width: number, height: number,
  zoom: number, offsetX: number, offsetY: number): CropRectangle {
  const scale = coverScale(imageWidth, imageHeight, width, height) * zoom;
  const cropWidth = Math.max(1, Math.min(imageWidth, Math.round(width / scale)));
  const cropHeight = Math.max(1, Math.min(imageHeight, Math.round(height / scale)));
  const x = Math.max(0, Math.min(imageWidth - cropWidth,
    Math.round((imageWidth - cropWidth) / 2 - offsetX / scale)));
  const y = Math.max(0, Math.min(imageHeight - cropHeight,
    Math.round((imageHeight - cropHeight) / 2 - offsetY / scale)));
  return { x, y, width: cropWidth, height: cropHeight };
}
