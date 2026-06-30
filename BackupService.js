function createDailyBackup() {

  const BACKUP_FOLDER_ID = "1FuRicJiOtskOUmE9hr65CeYpVyaZIkoO";

const ss = SpreadsheetApp.openById("13tFylpQlgxVu-6H86NRBrkoGbe7eoKoG6iBaPVJYUOE");
  const timestamp = Utilities.formatDate(
    new Date(),
    Session.getScriptTimeZone(),
    "yyyy-MM-dd_HH-mm"
  );

  const backupName =
    ss.getName() + "_Backup_" + timestamp;

  const file = DriveApp.getFileById(ss.getId());

  file.makeCopy(
    backupName,
    DriveApp.getFolderById(BACKUP_FOLDER_ID)
  );

  Logger.log("Backup Created: " + backupName);
}