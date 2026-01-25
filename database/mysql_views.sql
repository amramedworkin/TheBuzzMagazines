-- ============================================
-- MySQL Views converted from Access Queries
-- Database: advertisers
-- ============================================

USE advertisers;

-- ============================================
-- Simple lookup/reference views
-- ============================================

CREATE OR REPLACE VIEW vw_AcctExecs AS
SELECT tblAcctExecs.AcctExecID,
       tblAcctExecs.AcctExec,
       tblAcctExecs.Terminated
FROM tblAcctExecs
WHERE tblAcctExecs.Terminated = 0
ORDER BY tblAcctExecs.AcctExec;

CREATE OR REPLACE VIEW vw_CmbAcctExecID AS
SELECT tblAcctExecs.AcctExecID,
       tblAcctExecs.AcctExec
FROM tblAcctExecs
WHERE tblAcctExecs.Terminated = 0
ORDER BY tblAcctExecs.AcctExec;

CREATE OR REPLACE VIEW vw_CmbAE AS
SELECT tblAcctExecs.AcctExecID,
       tblAcctExecs.AcctExec
FROM tblAcctExecs
WHERE tblAcctExecs.Terminated = 0
ORDER BY tblAcctExecs.AcctExec;

CREATE OR REPLACE VIEW vw_CmbAdvertiserOrLead AS
SELECT tblProductCategories.AdvertiserOrLead,
       tblProductCategories.AorLDescr
FROM tblProductCategories
WHERE tblProductCategories.AdvertiserOrLead <> 'All'
ORDER BY tblProductCategories.SortSeq;

CREATE OR REPLACE VIEW vw_CmbAllAorP AS
SELECT tblProductCategories.AdvertiserOrLead,
       tblProductCategories.AorLDescr
FROM tblProductCategories
ORDER BY tblProductCategories.SortSeq;

CREATE OR REPLACE VIEW vw_CmbBusinessType AS
SELECT tblBusinessType.BusinessTypeID,
       tblBusinessType.BusinessType
FROM tblBusinessType
ORDER BY tblBusinessType.BusinessType;

CREATE OR REPLACE VIEW vw_CmbContactLevel AS
SELECT tblContactLevels.ContactLevel,
       tblContactLevels.SortSeq
FROM tblContactLevels
ORDER BY tblContactLevels.SortSeq;

CREATE OR REPLACE VIEW vw_ContractType AS
SELECT tblContractType.ContractType
FROM tblContractType
ORDER BY tblContractType.SortID;

CREATE OR REPLACE VIEW vw_Prefix AS
SELECT tblPrefix.Prefix
FROM tblPrefix
ORDER BY tblPrefix.SortSeq;

CREATE OR REPLACE VIEW vw_Suffix AS
SELECT tblSuffix.Suffix
FROM tblSuffix
ORDER BY tblSuffix.SortSeq;

CREATE OR REPLACE VIEW vw_StPostalCd AS
SELECT tblStPostalCd.ST
FROM tblStPostalCd
ORDER BY tblStPostalCd.ST;

CREATE OR REPLACE VIEW vw_CmdPrimaryContact AS
SELECT tblPrimaryContact.`Primary`,
       tblPrimaryContact.PrimarySeq
FROM tblPrimaryContact
ORDER BY tblPrimaryContact.PrimarySeq DESC;

-- ============================================
-- Core business views
-- ============================================

CREATE OR REPLACE VIEW vw_AdvPrimaryContacts AS
SELECT tblAdvContacts.AdvertiserID,
       tblAdvContacts.FName,
       tblAdvContacts.LName,
       tblAdvContacts.`Primary`
FROM tblAdvContacts
WHERE tblAdvContacts.`Primary` = 'Y';

CREATE OR REPLACE VIEW vw_CommentDateLatest AS
SELECT tblComments.AdvertiserID,
       MAX(tblComments.CommentDate) AS `Last Contact`
FROM tblComments
GROUP BY tblComments.AdvertiserID;

CREATE OR REPLACE VIEW vw_Advertisers AS
SELECT tblAdvertisers.AdvertiserID,
       tblAdvertisers.Advertiser,
       tblAdvertisers.Street,
       tblAdvertisers.Suite,
       tblAdvertisers.City,
       tblAdvertisers.ST,
       tblAdvertisers.ZIP,
       tblAdvertisers.Contact,
       tblAdvertisers.Title,
       tblAdvertisers.Phone,
       tblAdvertisers.PhExt,
       tblAdvertisers.Fax,
       tblAdvertisers.Email,
       tblAdvertisers.AlternateContact,
       tblAdvertisers.AcctExecID,
       tblAdvertisers.EntryDate,
       tblAdvertisers.AdvertiserOrLead,
       tblAdvertisers.LastContactDate,
       tblAdvertisers.Comments,
       tblAdvertisers.InitialContactDate,
       tblAdvertisers.Dead,
       tblAdvertisers.Temp,
       tblAdvertisers.Active,
       tblAdvertisers.ContractExpires,
       tblAdvertisers.BusinessType,
       tblAdvertisers.ContractType,
       tblAdvertisers.Website
FROM tblAdvertisers
ORDER BY tblAdvertisers.Advertiser;

CREATE OR REPLACE VIEW vw_SelectAdvertiser AS
SELECT tblAdvertisers.Advertiser,
       tblAdvertisers.Street,
       tblAdvertisers.City,
       tblAdvertisers.ZIP
FROM tblAdvertisers
ORDER BY tblAdvertisers.Advertiser;

CREATE OR REPLACE VIEW vw_SfrmAdvContacts AS
SELECT tblAdvContacts.PrimarySeq,
       tblAdvContacts.ContactID,
       tblAdvContacts.AdvertiserID,
       tblAdvContacts.ContactLevelSeq,
       tblAdvContacts.LName,
       tblAdvContacts.FName,
       tblAdvContacts.Prefix,
       tblAdvContacts.Suffix,
       tblAdvContacts.CoTitle,
       tblAdvContacts.EMail,
       tblAdvContacts.Ph,
       tblAdvContacts.PhExt,
       tblAdvContacts.Street,
       tblAdvContacts.Suite,
       tblAdvContacts.City,
       tblAdvContacts.ST,
       tblAdvContacts.ZIP,
       tblAdvContacts.Organization,
       tblAdvContacts.ContactLevel,
       tblAdvContacts.PhCell,
       tblAdvContacts.PhFax,
       tblAdvContacts.`Primary`,
       tblAdvContacts.Website
FROM tblAdvContacts
ORDER BY tblAdvContacts.PrimarySeq;

-- ============================================
-- List views (with proper JOINs)
-- ============================================

CREATE OR REPLACE VIEW vw_ContactList AS
SELECT tblAdvertisers.Advertiser,
       tblAdvertisers.Contact,
       tblAdvertisers.Phone,
       tblAcctExecs.AcctExec,
       tblAdvertisers.InitialContactDate,
       tblAdvertisers.LastContactDate,
       tblAdvertisers.Dead,
       tblAdvertisers.AdvertiserOrLead,
       tblAdvertisers.AdvertiserID
FROM tblAdvertisers
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
WHERE tblAdvertisers.AdvertiserOrLead = 'L'
ORDER BY tblAdvertisers.Advertiser;

CREATE OR REPLACE VIEW vw_ProspectList AS
SELECT tblAdvertisers.Advertiser,
       tblAdvertisers.Contact,
       tblAdvertisers.Phone,
       tblAcctExecs.AcctExec,
       tblAdvertisers.InitialContactDate,
       tblAdvertisers.LastContactDate,
       tblAdvertisers.Dead,
       tblAdvertisers.AdvertiserOrLead,
       tblAdvertisers.AdvertiserID
FROM tblAdvertisers
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
WHERE tblAdvertisers.AdvertiserOrLead = 'P'
ORDER BY tblAdvertisers.Advertiser;

CREATE OR REPLACE VIEW vw_ChronologicalComments AS
SELECT tblAdvertisers.Advertiser,
       tblAcctExecs.AcctExec,
       tblComments.CommentDate,
       tblComments.CommentTime,
       tblComments.Comment
FROM tblComments
JOIN tblAdvertisers ON tblComments.AdvertiserID = tblAdvertisers.AdvertiserID
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
ORDER BY tblComments.CommentDate;

CREATE OR REPLACE VIEW vw_ChronologicalCommentsTemplate AS
SELECT CONCAT(tblAdvertisers.Advertiser, ' ', tblAdvertisers.Street) AS AdvertiserStreet,
       tblAcctExecs.AcctExec,
       tblComments.CommentDate,
       tblComments.CommentTime,
       tblComments.Comment
FROM tblComments
JOIN tblAdvertisers ON tblComments.AdvertiserID = tblAdvertisers.AdvertiserID
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
ORDER BY CONCAT(tblAdvertisers.Advertiser, ' ', tblAdvertisers.Street);

CREATE OR REPLACE VIEW vw_RptAdvertisers AS
SELECT tblAdvertisers.Advertiser,
       tblAdvertisers.Contact,
       tblAcctExecs.AcctExec,
       tblAdvertisers.LastContactDate,
       tblAdvertisers.AdvertiserOrLead,
       tblAdvertisers.InitialContactDate,
       tblAdvertisers.ContractExpires,
       tblAdvertisers.ContractType,
       vw_CommentDateLatest.`Last Contact`,
       tblAdvertisers.Temp
FROM tblAdvertisers
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
LEFT JOIN vw_CommentDateLatest ON tblAdvertisers.AdvertiserID = vw_CommentDateLatest.AdvertiserID
ORDER BY tblAdvertisers.Advertiser;

CREATE OR REPLACE VIEW vw_ListTemplate AS
SELECT tblAdvertisers.Advertiser,
       tblAdvertisers.Contact,
       tblAdvertisers.Phone,
       tblAdvertisers.AdvertiserOrLead,
       tblAcctExecs.AcctExec,
       tblAdvertisers.InitialContactDate,
       vw_CommentDateLatest.`Last Contact`,
       tblAdvertisers.Temp,
       tblAdvertisers.Active,
       tblAdvertisers.AdvertiserID
FROM tblAdvertisers
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
LEFT JOIN vw_CommentDateLatest ON tblAdvertisers.AdvertiserID = vw_CommentDateLatest.AdvertiserID;

-- ============================================
-- Advertiser list with primary contact
-- ============================================

CREATE OR REPLACE VIEW vw_AdvertiserList AS
SELECT tblAdvertisers.AdvertiserID,
       tblAdvertisers.Advertiser,
       CONCAT(vw_AdvPrimaryContacts.FName, ' ', vw_AdvPrimaryContacts.LName) AS PrimaryContact,
       tblAdvertisers.Street,
       tblAdvertisers.City,
       tblAdvertisers.St,
       tblAdvertisers.Zip,
       tblAdvertisers.Phone,
       tblAdvertisers.PhExt,
       tblAdvertisers.Email,
       tblAcctExecs.AcctExec AS `Account Manager`,
       tblAdvertisers.AdvertiserOrLead AS Category,
       tblAdvertisers.ContractExpires AS `Contract Expires`,
       tblAdvertisers.InitialContactDate AS `Initial Contact`,
       vw_CommentDateLatest.`Last Contact`,
       tblAdvertisers.Temp,
       tblAdvertisers.Active,
       tblBusinessType.BusinessType
FROM tblAdvertisers
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
LEFT JOIN vw_CommentDateLatest ON tblAdvertisers.AdvertiserID = vw_CommentDateLatest.AdvertiserID
LEFT JOIN tblBusinessType ON tblAdvertisers.BusinessType = tblBusinessType.BusinessTypeID
LEFT JOIN vw_AdvPrimaryContacts ON tblAdvertisers.AdvertiserID = vw_AdvPrimaryContacts.AdvertiserID
ORDER BY tblAdvertisers.Advertiser;

-- ============================================
-- Export views with contacts
-- ============================================

CREATE OR REPLACE VIEW vw_AdvertiserListExport AS
SELECT vw_AdvertiserList.AdvertiserID,
       vw_AdvertiserList.Advertiser,
       vw_AdvertiserList.Street,
       vw_AdvertiserList.City,
       vw_AdvertiserList.St,
       vw_AdvertiserList.Zip,
       vw_AdvertiserList.Phone,
       vw_AdvertiserList.PhExt,
       vw_AdvertiserList.Email,
       vw_AdvertiserList.`Account Manager`,
       vw_AdvertiserList.Category,
       vw_AdvertiserList.`Contract Expires`,
       vw_AdvertiserList.`Initial Contact`,
       vw_AdvertiserList.`Last Contact`,
       vw_AdvertiserList.Temp,
       vw_AdvertiserList.Active,
       vw_AdvertiserList.BusinessType,
       CONCAT_WS(' ', tblAdvContacts.Prefix, tblAdvContacts.FName, tblAdvContacts.LName, tblAdvContacts.Suffix) AS ContactFullName,
       tblAdvContacts.`Primary`,
       tblAdvContacts.FName,
       tblAdvContacts.LName,
       tblAdvContacts.Prefix,
       tblAdvContacts.Suffix,
       tblAdvContacts.CoTitle,
       tblAdvContacts.EMail AS ContactEmail,
       tblAdvContacts.Ph,
       tblAdvContacts.PhExt AS ContactPhExt,
       tblAdvContacts.Street AS ContactStreet,
       tblAdvContacts.Suite,
       tblAdvContacts.City AS ContactCity,
       tblAdvContacts.ST AS ContactST,
       tblAdvContacts.ZIP AS ContactZIP,
       tblAdvContacts.Organization,
       tblAdvContacts.ContactLevel,
       tblAdvContacts.PhCell,
       tblAdvContacts.PhFax,
       tblAdvContacts.PrimarySeq
FROM vw_AdvertiserList
JOIN tblAdvContacts ON vw_AdvertiserList.AdvertiserID = tblAdvContacts.AdvertiserID
ORDER BY vw_AdvertiserList.Advertiser;

CREATE OR REPLACE VIEW vw_AdvertiserListExportPrimary AS
SELECT vw_AdvertiserList.AdvertiserID,
       vw_AdvertiserList.Advertiser,
       vw_AdvertiserList.Street,
       vw_AdvertiserList.City,
       vw_AdvertiserList.St,
       vw_AdvertiserList.Zip,
       vw_AdvertiserList.Phone,
       vw_AdvertiserList.PhExt,
       vw_AdvertiserList.Email,
       vw_AdvertiserList.`Account Manager`,
       vw_AdvertiserList.Category,
       vw_AdvertiserList.`Contract Expires`,
       vw_AdvertiserList.`Initial Contact`,
       vw_AdvertiserList.`Last Contact`,
       vw_AdvertiserList.Temp,
       vw_AdvertiserList.Active,
       vw_AdvertiserList.BusinessType,
       CONCAT_WS(' ', tblAdvContacts.Prefix, tblAdvContacts.FName, tblAdvContacts.LName, tblAdvContacts.Suffix) AS ContactFullName,
       tblAdvContacts.`Primary`,
       tblAdvContacts.FName,
       tblAdvContacts.LName,
       tblAdvContacts.Prefix,
       tblAdvContacts.Suffix,
       tblAdvContacts.CoTitle,
       tblAdvContacts.EMail AS ContactEmail,
       tblAdvContacts.Ph,
       tblAdvContacts.PhExt AS ContactPhExt,
       tblAdvContacts.Street AS ContactStreet,
       tblAdvContacts.Suite,
       tblAdvContacts.City AS ContactCity,
       tblAdvContacts.ST AS ContactST,
       tblAdvContacts.ZIP AS ContactZIP,
       tblAdvContacts.Organization,
       tblAdvContacts.ContactLevel,
       tblAdvContacts.PhCell,
       tblAdvContacts.PhFax,
       tblAdvContacts.PrimarySeq
FROM vw_AdvertiserList
JOIN tblAdvContacts ON vw_AdvertiserList.AdvertiserID = tblAdvContacts.AdvertiserID
WHERE tblAdvContacts.`Primary` = 'Y'
ORDER BY vw_AdvertiserList.Advertiser;

-- ============================================
-- Null contact finding views
-- ============================================

CREATE OR REPLACE VIEW vw_NullAdvContacts AS
SELECT tblAdvertisers.Contact,
       tblAdvertisers.AdvertiserID,
       tblAdvertisers.Advertiser
FROM tblAdvertisers
WHERE tblAdvertisers.Contact IS NULL
ORDER BY tblAdvertisers.Advertiser;

CREATE OR REPLACE VIEW vw_NullAdvAltContacts AS
SELECT tblAdvertisers.AlternateContact,
       tblAdvertisers.AdvertiserID,
       tblAdvertisers.Advertiser
FROM tblAdvertisers
WHERE tblAdvertisers.AlternateContact IS NULL
ORDER BY tblAdvertisers.Advertiser;

-- ============================================
-- Duplicate finding views
-- ============================================

CREATE OR REPLACE VIEW vw_DuplicateAdvertisers AS
SELECT tblAdvertisers.Advertiser,
       tblAdvertisers.Street,
       tblAdvertisers.Contact,
       tblAcctExecs.AcctExec
FROM tblAdvertisers
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
WHERE tblAdvertisers.Advertiser IN (
    SELECT Tmp.Advertiser 
    FROM tblAdvertisers AS Tmp 
    GROUP BY Tmp.Advertiser 
    HAVING COUNT(*) > 1
)
ORDER BY tblAdvertisers.Advertiser;

CREATE OR REPLACE VIEW vw_DuplicateAdvertisersByStreet AS
SELECT tblAdvertisers.Advertiser,
       tblAdvertisers.Street,
       tblAdvertisers.Contact,
       tblAcctExecs.AcctExec
FROM tblAdvertisers
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
WHERE tblAdvertisers.Advertiser IN (
    SELECT Tmp.Advertiser 
    FROM tblAdvertisers AS Tmp 
    GROUP BY Tmp.Advertiser, Tmp.Street 
    HAVING COUNT(*) > 1 AND Tmp.Street = tblAdvertisers.Street
)
ORDER BY tblAdvertisers.Advertiser;

-- ============================================
-- Street/Suite concatenation views
-- ============================================

CREATE OR REPLACE VIEW vw_Concat_StreetAndSuite AS
SELECT 'tblAdvContacts' AS TableName,
       tblAdvContacts.ContactID,
       tblAdvContacts.AdvertiserID,
       tblAdvertisers.Advertiser,
       tblAcctExecs.AcctExec,
       tblAdvertisers.AdvertiserOrLead,
       tblAdvContacts.Street,
       tblAdvContacts.Suite,
       CONCAT(tblAdvContacts.Street, ', Suite ', tblAdvContacts.Suite) AS CombinedAddress
FROM tblAdvContacts
JOIN tblAdvertisers ON tblAdvContacts.AdvertiserID = tblAdvertisers.AdvertiserID
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
WHERE tblAdvContacts.Street NOT LIKE CONCAT('%', tblAdvContacts.Suite, '%')
  AND tblAdvContacts.Suite IS NOT NULL;

CREATE OR REPLACE VIEW vw_Concat_StreetAndSuite_5 AS
SELECT 'tblAdvertisers' AS TableName,
       '' AS ContactID,
       tblAdvertisers.AdvertiserID,
       tblAdvertisers.Advertiser,
       tblAcctExecs.AcctExec,
       tblAdvertisers.AdvertiserOrLead,
       tblAdvertisers.Street,
       tblAdvertisers.Suite,
       CONCAT(tblAdvertisers.Street, ', Suite ', tblAdvertisers.Suite) AS CombinedAddress
FROM tblAdvertisers
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
WHERE tblAdvertisers.Street NOT LIKE '%Suite%'
  AND tblAdvertisers.Street NOT LIKE '%ste%'
  AND tblAdvertisers.Suite IS NOT NULL
  AND tblAdvertisers.Suite NOT LIKE '%Suite%';

CREATE OR REPLACE VIEW vw_Concat_StreetAndSuite_6 AS
SELECT 'tblAdvertisers' AS TableName,
       '' AS ContactID,
       tblAdvertisers.AdvertiserID,
       tblAdvertisers.Advertiser,
       tblAcctExecs.AcctExec,
       tblAdvertisers.AdvertiserOrLead,
       tblAdvertisers.Street,
       tblAdvertisers.Suite,
       CONCAT(tblAdvertisers.Street, ',  ', tblAdvertisers.Suite) AS CombinedAddress
FROM tblAdvertisers
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
WHERE tblAdvertisers.Street NOT LIKE '%Suite%'
  AND tblAdvertisers.Street NOT LIKE '%ste%'
  AND tblAdvertisers.Suite LIKE '%Suite%';

-- ============================================
-- Contact creation helper views
-- ============================================

CREATE OR REPLACE VIEW vw_CreateTblAdvContacts AS
SELECT tblAdvertisers.AdvertiserID,
       IF(LOCATE(' ', tblAdvertisers.Contact) = 0, 
          '', 
          SUBSTRING(tblAdvertisers.Contact, LOCATE(' ', tblAdvertisers.Contact) + 1)) AS LName,
       IF(LOCATE(' ', tblAdvertisers.Contact) = 0, 
          tblAdvertisers.Contact, 
          LEFT(tblAdvertisers.Contact, LOCATE(' ', tblAdvertisers.Contact) - 1)) AS FName,
       NULL AS Prefix,
       NULL AS Suffix,
       tblAdvertisers.Title,
       tblAdvertisers.Email,
       tblAdvertisers.Phone,
       tblAdvertisers.PhExt,
       tblAdvertisers.Street,
       tblAdvertisers.Suite,
       tblAdvertisers.City,
       tblAdvertisers.ST,
       tblAdvertisers.ZIP,
       tblAdvertisers.Advertiser AS Organization,
       'Primary' AS ContactLevel,
       1 AS PrimarySeq,
       NULL AS PhCell,
       NULL AS PhFax,
       LOCATE(' ', tblAdvertisers.Contact) AS FirstBlank
FROM tblAdvertisers
WHERE LOCATE(' ', tblAdvertisers.Contact) IS NOT NULL;

CREATE OR REPLACE VIEW vw_CreateTblAdvContactsAlt AS
SELECT tblAdvertisers.AdvertiserID,
       IF(LOCATE(' ', tblAdvertisers.AlternateContact) = 0, 
          '', 
          SUBSTRING(tblAdvertisers.AlternateContact, LOCATE(' ', tblAdvertisers.AlternateContact) + 1)) AS LName,
       IF(LOCATE(' ', tblAdvertisers.AlternateContact) = 0, 
          tblAdvertisers.AlternateContact, 
          LEFT(tblAdvertisers.AlternateContact, LOCATE(' ', tblAdvertisers.AlternateContact) - 1)) AS FName,
       NULL AS Prefix,
       NULL AS Suffix,
       NULL AS Title,
       tblAdvertisers.Email,
       tblAdvertisers.Phone,
       tblAdvertisers.PhExt,
       tblAdvertisers.Street,
       tblAdvertisers.Suite,
       tblAdvertisers.City,
       tblAdvertisers.ST,
       tblAdvertisers.ZIP,
       tblAdvertisers.Advertiser AS Organization,
       'Alternate' AS ContactLevel,
       2 AS PrimarySeq,
       LOCATE(' ', tblAdvertisers.AlternateContact) AS FirstBlank,
       NULL AS PhCell,
       NULL AS PhFax
FROM tblAdvertisers
WHERE LOCATE(' ', tblAdvertisers.AlternateContact) IS NOT NULL;

-- ============================================
-- Aggregate/count views
-- ============================================

CREATE OR REPLACE VIEW vw_AdvertiserCount AS
SELECT COUNT(tblAdvertisers.AdvertiserID) AS TotalAdvertisers
FROM tblAdvertisers;

CREATE OR REPLACE VIEW vw_ProspectsByAcctExec AS
SELECT tblAdvertisers.AdvertiserID,
       tblAdvertisers.AcctExecID,
       tblAdvertisers.AdvertiserOrLead
FROM tblAdvertisers
WHERE tblAdvertisers.AdvertiserOrLead = 'P'
ORDER BY tblAdvertisers.AcctExecID;

-- ============================================
-- Excel import helper views
-- (Assumes ExcelAdvertisers and ExcelLeads tables exist)
-- ============================================

-- CREATE OR REPLACE VIEW vw_ConvertAdvertisers AS
-- SELECT ExcelAdvertisers.Advertiser,
--        ExcelAdvertisers.AcctExecID,
--        ExcelAdvertisers.AdvertiserOrLead
-- FROM ExcelAdvertisers;

-- CREATE OR REPLACE VIEW vw_ConvertLeads AS
-- SELECT ExcelLeads.Advertiser,
--        ExcelLeads.AcctExecID,
--        ExcelLeads.AdvertiserOrLead
-- FROM ExcelLeads;

-- ============================================
-- STORED PROCEDURES
-- These replace Access queries that referenced form controls
-- ============================================

DELIMITER //

-- Replaces qrySfrmComments (referenced Forms!frmAdvertisers!AdvertiserID)
CREATE PROCEDURE sp_SfrmComments(IN p_AdvertiserID INT)
BEGIN
    SELECT tblComments.CommentID,
           tblComments.AdvertiserID,
           tblComments.CommentDate,
           tblComments.CommentTime,
           tblComments.Comment,
           tblAcctExecs.AcctExec
    FROM tblComments
    JOIN tblAcctExecs ON tblComments.AcctExecID = tblAcctExecs.AcctExecID
    WHERE tblComments.AdvertiserID = p_AdvertiserID
    ORDER BY tblComments.CommentDate;
END //

-- Replaces Query2 (referenced Forms!frmAdvertisers!cmbAcctExecID)
CREATE PROCEDURE sp_AdvertisersByAcctExec(IN p_AcctExecID INT)
BEGIN
    SELECT tblAdvertisers.AcctExecID,
           tblAdvertisers.AdvertiserOrLead
    FROM tblAdvertisers
    WHERE tblAdvertisers.AcctExecID = p_AcctExecID
      AND tblAdvertisers.AdvertiserOrLead = 'L';
END //

-- Replaces Query4 (referenced Forms!frmAdvertisers!cmbAdvertiserOrLead)
CREATE PROCEDURE sp_PPAMaxQty(IN p_AdvertiserOrLead VARCHAR(10))
BEGIN
    SELECT tblPPAMaxQty.AdvertiserOrLead,
           tblPPAMaxQty.MaxQty
    FROM tblPPAMaxQty
    WHERE tblPPAMaxQty.AdvertiserOrLead = p_AdvertiserOrLead;
END //

-- Replaces QryTest (referenced Forms!frmAdvertiserAndContactLists!txtSelectAdvertiser)
CREATE PROCEDURE sp_SearchAdvertisers(IN p_SearchTerm VARCHAR(255))
BEGIN
    SELECT tblAdvertisers.Advertiser,
           tblAdvertisers.Contact,
           tblAdvertisers.Phone,
           tblAcctExecs.AcctExec,
           tblAdvertisers.LastContactDate,
           tblAdvertisers.AdvertiserOrLead,
           tblAdvertisers.AdvertiserID
    FROM tblAdvertisers
    JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
    WHERE tblAdvertisers.Advertiser LIKE CONCAT(p_SearchTerm, '%')
      AND tblAdvertisers.AdvertiserOrLead = 'A'
    ORDER BY tblAdvertisers.Advertiser;
END //

-- Replaces Query5 (specific advertiser contacts lookup)
CREATE PROCEDURE sp_ContactsByAdvertiser(IN p_AdvertiserID INT)
BEGIN
    SELECT tblAdvContacts.ContactID,
           tblAdvContacts.AdvertiserID,
           tblAdvContacts.FName,
           tblAdvContacts.LName,
           tblAdvContacts.`Primary`,
           tblAdvContacts.PrimarySeq,
           tblAdvContacts.ContactLevel,
           tblAdvContacts.ContactLevelSeq
    FROM tblAdvContacts
    WHERE tblAdvContacts.AdvertiserID = p_AdvertiserID;
END //

DELIMITER ;

-- ============================================
-- NOTES:
-- 
-- 1. Views are created in dependency order - base views first,
--    then views that reference other views.
--
-- 2. `Primary` is a MySQL reserved word, so it's wrapped in backticks.
--
-- 3. JOIN conditions assume AcctExecID is the foreign key linking
--    tblAdvertisers to tblAcctExecs. Verify your actual schema.
--
-- 4. The Excel import views are commented out since those tables
--    may not exist in your MySQL database.
--
-- 5. Stored procedures replace Access queries that had form references.
--    Call them like: CALL sp_SfrmComments(12345);
--
-- 6. Original Access queries with empty SELECT lists were skipped:
--    - ~sq_ffrmContactLevels, ~sq_ffrmPrefix, ~sq_ffrmSecurity
--    - ~sq_ffrmPPAMaxQty, ~sq_ffrmProductCategories, ~sq_ffrmSuffix
--    - qry_CONCAT_Merge_5and6, qry_CONCAT_MergeAllSuiteChanges
--    - qry_CONCAT_FullPop
-- ============================================
