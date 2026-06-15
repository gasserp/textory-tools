export const overlay = $state<{ palette: boolean; help: boolean; admin: boolean; settings: boolean }>({
  palette: false,
  help: false,
  admin: false,
  settings: false,
});

export function togglePalette(): void {
  if (overlay.palette) {
    overlay.palette = false;
    return;
  }
  overlay.palette = true;
  overlay.help = false;
  overlay.admin = false;
  overlay.settings = false;
}

export function openHelp(): void {
  overlay.help = true;
  overlay.palette = false;
  overlay.admin = false;
  overlay.settings = false;
}

export function openAdmin(): void {
  overlay.admin = true;
  overlay.palette = false;
  overlay.help = false;
  overlay.settings = false;
}

export function openSettings(): void {
  overlay.settings = true;
  overlay.palette = false;
  overlay.help = false;
  overlay.admin = false;
}

export function closeOverlays(): void {
  overlay.palette = false;
  overlay.help = false;
  overlay.admin = false;
  overlay.settings = false;
}
