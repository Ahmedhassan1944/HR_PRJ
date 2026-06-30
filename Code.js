/**
 * =========================================================
 * ENTERPRISE HR MOBILIZATION SYSTEM - BACKEND CONTROLLER
 * =========================================================
 */

/**
 * Standard GET handler. Evaluates and serves the Index.html template.
 */
function doGet(e) {
  return HtmlService.createTemplateFromFile('Index')
    .evaluate()
    .setTitle('Enterprise HR Mobilization')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL); // Required if embedding
}

/**
 * Helper function to inject Styles.html and Script.html into Index.html.
 */
function include(filename) {
  return HtmlService.createHtmlOutputFromFile(filename).getContent();
}

/**
 * =========================================================
 * API LAYER -> To be called via google.script.run
 * =========================================================
 */

/**
 * Fetches and aggregates dashboard KPI data from the Candidates sheet.
 * Statuses covered:
 *   Missing Docs  → New Candidate | Documents Requested | Pending Passport |
 *                   Pending Photo | Pending Academic Certificate | Pending Medical
 *   Visa Pending  → Visa Pending
 *   Visa Completed→ Visa Completed
 *   Mobilized     → Mobilized
 *   Active Cases  → everything except Closed
 */
function api_getDashboardData() {
  try {
    const res = api_getAllCandidates();
    if (!res.success) throw new Error(res.error);

    const MISSING_DOC_STATUSES = new Set([
      'New Candidate',
      'Documents Requested',
      'Pending Passport',
      'Pending Photo',
      'Pending Academic Certificate',
      'Pending Medical'
    ]);

    let activeCount    = 0;
    let missingDocs    = 0;
    let visaPending    = 0;
    let visaCompleted  = 0;
    let mobilized      = 0;

    res.data.forEach(cand => {
      const status = (cand.CurrentStatus || '').trim();

      if (status !== 'Closed') activeCount++;

      if (MISSING_DOC_STATUSES.has(status))  missingDocs++;
      else if (status === 'Visa Pending')     visaPending++;
      else if (status === 'Visa Completed')   visaCompleted++;
      else if (status === 'Mobilized')        mobilized++;
    });

    return {
      success: true,
      data: {
        activeCount:   activeCount,
        missingDocs:   missingDocs,
        visaPending:   visaPending,
        visaCompleted: visaCompleted,
        mobilized:     mobilized,
        msg: 'Live data successfully retrieved from Google Sheets.'
      }
    };
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
