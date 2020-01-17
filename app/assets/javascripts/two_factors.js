function copyBackupCodes(event) {
  var el = document.getElementById('copy-backup-codes-button');
  var backup_codes_data = el.getAttribute('data-text');
  navigator.clipboard.writeText(backup_codes_data);
  $(el).tooltip({ title: el.getAttribute('data-copied'), trigger: 'manual' });
  $(el).tooltip('show');
  setTimeout(function() {
    $(el).tooltip('hide');
  }, 1000);
  event.preventDefault();
}

function closePrintBackupCodes(event) {
  window.close()
}

function initializeBackupCodes() {
  let copyButton = document.getElementById('copy-backup-codes-button');
  if (copyButton && navigator.clipboard) {
    copyButton.classList.remove('d-none');
    copyButton.addEventListener('click', copyBackupCodes);
  }

  let closeButton = document.getElementById('close-print-backup-codes-button');
  if (closeButton) {
    window.print();
    setTimeout(window.close, 1000);
    closeButton.addEventListener('click', closePrintBackupCodes);
  }
}

if (document.readyState === 'loading') {
  document.addEventListener(
    'DOMContentLoaded',
    initializeBackupCodes,
    { once: true, passive: true }
  );
} else { // `DOMContentLoaded` already fired
  initializeBackupCodes();
}
