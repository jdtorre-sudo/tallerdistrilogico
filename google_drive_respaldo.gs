/**
 * Receptor de respaldos en Google Drive (Google Apps Script).
 * Se instala UNA vez desde https://script.google.com con su cuenta de Gmail
 * (instrucciones paso a paso en LEEME.md, sección "Respaldo en Google Drive").
 *
 * Guarda cada respaldo en la carpeta "Respaldos Taller Distrilogico" y
 * conserva solo los últimos 12 (unos 3 meses de respaldos semanales).
 */

// 1) Cambie este texto por una clave larga inventada por usted.
//    La misma clave va en GitHub como secreto DRIVE_SCRIPT_TOKEN.
const CLAVE = 'CAMBIE-ESTA-CLAVE-POR-UNA-LARGA-Y-SECRETA';
const CARPETA = 'Respaldos Taller Distrilogico';
const CONSERVAR = 12;

function doPost(e) {
  try {
    const d = JSON.parse(e.postData.contents);
    if (d.token !== CLAVE) return respuesta({ ok: false, error: 'clave incorrecta' });
    const carpetas = DriveApp.getFoldersByName(CARPETA);
    const carpeta = carpetas.hasNext() ? carpetas.next() : DriveApp.createFolder(CARPETA);
    const blob = Utilities.newBlob(Utilities.base64Decode(d.contenido), 'application/zip', d.nombre);
    const archivo = carpeta.createFile(blob);
    limpiar(carpeta);
    return respuesta({ ok: true, id: archivo.getId(), nombre: d.nombre });
  } catch (err) {
    return respuesta({ ok: false, error: String(err) });
  }
}

function limpiar(carpeta) {
  const lista = [];
  const it = carpeta.getFiles();
  while (it.hasNext()) lista.push(it.next());
  lista.sort((a, b) => b.getDateCreated() - a.getDateCreated());
  lista.slice(CONSERVAR).forEach(f => f.setTrashed(true));
}

function respuesta(o) {
  return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON);
}

// Ejecute esta función una vez desde el editor para dar permiso a Drive.
function probar() {
  const carpetas = DriveApp.getFoldersByName(CARPETA);
  const carpeta = carpetas.hasNext() ? carpetas.next() : DriveApp.createFolder(CARPETA);
  Logger.log('Carpeta lista: ' + carpeta.getUrl());
}
