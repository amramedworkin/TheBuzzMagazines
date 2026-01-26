-- ============================================================================
-- MySQL Views/Stored Procedures converted from MS Access Queries
-- Database: advertisers
-- 
-- IMPORTANT: Object names are kept EXACTLY the same as MS Access for
-- cross-reference compatibility.
--
-- Dependencies are ordered - base views first, then dependent views.
-- ============================================================================

USE advertisers;

-- ============================================================================
-- LEVEL 0: Base views with NO query dependencies (only table dependencies)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Lookup/Reference Views
-- ----------------------------------------------------------------------------

-- Access: qryAcctExecs
CREATE OR REPLACE VIEW `qryAcctExecs` AS
SELECT tblAcctExecs.AcctExecID,
       tblAcctExecs.AcctExec,
       tblAcctExecs.Terminated
FROM tblAcctExecs
WHERE tblAcctExecs.Terminated = 0
ORDER BY tblAcctExecs.AcctExec;

-- Access: qryCmbAcctExecID
CREATE OR REPLACE VIEW `qryCmbAcctExecID` AS
SELECT tblAcctExecs.AcctExecID,
       tblAcctExecs.AcctExec
FROM tblAcctExecs
WHERE tblAcctExecs.Terminated = 0
ORDER BY tblAcctExecs.AcctExec;

-- Access: qryCmbAE
CREATE OR REPLACE VIEW `qryCmbAE` AS
SELECT tblAcctExecs.AcctExecID,
       tblAcctExecs.AcctExec
FROM tblAcctExecs
WHERE tblAcctExecs.Terminated = 0
ORDER BY tblAcctExecs.AcctExec;

-- Access: qryCmbAdvertiserOrLead
CREATE OR REPLACE VIEW `qryCmbAdvertiserOrLead` AS
SELECT tblProductCategories.AdvertiserOrLead,
       tblProductCategories.AorLDescr
FROM tblProductCategories
WHERE tblProductCategories.AdvertiserOrLead <> 'All'
ORDER BY tblProductCategories.SortSeq;

-- Access: qryCmbAllAorP
CREATE OR REPLACE VIEW `qryCmbAllAorP` AS
SELECT tblProductCategories.AdvertiserOrLead,
       tblProductCategories.AorLDescr
FROM tblProductCategories
ORDER BY tblProductCategories.SortSeq;

-- Access: qryCmbBusinessType
CREATE OR REPLACE VIEW `qryCmbBusinessType` AS
SELECT tblBusinessType.BusinessTypeID,
       tblBusinessType.BusinessType
FROM tblBusinessType
ORDER BY tblBusinessType.BusinessType;

-- Access: qryCmbContactLevel
CREATE OR REPLACE VIEW `qryCmbContactLevel` AS
SELECT tblContactLevels.ContactLevel,
       tblContactLevels.SortSeq
FROM tblContactLevels
ORDER BY tblContactLevels.SortSeq;

-- Access: qryContractType
CREATE OR REPLACE VIEW `qryContractType` AS
SELECT tblContractType.ContractType
FROM tblContractType
ORDER BY tblContractType.SortSeq;

-- Access: qryPrefix
CREATE OR REPLACE VIEW `qryPrefix` AS
SELECT tblPrefix.Prefix
FROM tblPrefix
ORDER BY tblPrefix.SortSeq;

-- Access: qrySuffix
CREATE OR REPLACE VIEW `qrySuffix` AS
SELECT tblSuffix.Suffix
FROM tblSuffix
ORDER BY tblSuffix.SortSeq;

-- Access: qryStPostalCd
CREATE OR REPLACE VIEW `qryStPostalCd` AS
SELECT tblStPostalCd.ST
FROM tblStPostalCd
ORDER BY tblStPostalCd.ST;

-- Access: qryCmdPrimaryContact
CREATE OR REPLACE VIEW `qryCmdPrimaryContact` AS
SELECT tblPrimaryContact.`Primary`,
       tblPrimaryContact.PrimarySeq
FROM tblPrimaryContact
ORDER BY tblPrimaryContact.PrimarySeq DESC;

-- ----------------------------------------------------------------------------
-- Core Data Views (single table)
-- ----------------------------------------------------------------------------

-- Access: qryCommentDateLatest
-- Note: Original had ORDER BY in aggregate - MySQL requires GROUP BY
CREATE OR REPLACE VIEW `qryCommentDateLatest` AS
SELECT tblComments.AdvertiserID,
       MAX(tblComments.CommentDate) AS `Last Contact`
FROM tblComments
GROUP BY tblComments.AdvertiserID;

-- Access: qryAdvPrimaryContacts
CREATE OR REPLACE VIEW `qryAdvPrimaryContacts` AS
SELECT tblAdvContacts.AdvertiserID,
       tblAdvContacts.FName,
       tblAdvContacts.LName,
       tblAdvContacts.`Primary`
FROM tblAdvContacts
WHERE tblAdvContacts.`Primary` = 'Y';

-- Access: qryAdvertisers
CREATE OR REPLACE VIEW `qryAdvertisers` AS
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

-- Access: qrySelectAdvertiser
CREATE OR REPLACE VIEW `qrySelectAdvertiser` AS
SELECT tblAdvertisers.Advertiser,
       tblAdvertisers.Street,
       tblAdvertisers.City,
       tblAdvertisers.ZIP
FROM tblAdvertisers
ORDER BY tblAdvertisers.Advertiser;

-- Access: qrySfrmAdvContacts
CREATE OR REPLACE VIEW `qrySfrmAdvContacts` AS
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

-- Access: qryAlternateContact
CREATE OR REPLACE VIEW `qryAlternateContact` AS
SELECT 2 AS ContactLevelSeq
FROM tblAdvContacts
WHERE tblAdvContacts.ContactLevel = 'Alternate';

-- Access: qryContactLvlClient
CREATE OR REPLACE VIEW `qryContactLvlClient` AS
SELECT 'Client' AS ContactLevel,
       1 AS SortSeq
FROM tblAdvContacts;

-- Access: qryPrimaryContact
CREATE OR REPLACE VIEW `qryPrimaryContact` AS
SELECT 'X' AS Flag,
       1 AS SortSeq
FROM tblAdvContacts
WHERE tblAdvContacts.ContactLevel = 'Primary';

-- Access: qryNullAdvContacts
CREATE OR REPLACE VIEW `qryNullAdvContacts` AS
SELECT tblAdvertisers.Contact,
       tblAdvertisers.AdvertiserID,
       tblAdvertisers.Advertiser
FROM tblAdvertisers
WHERE tblAdvertisers.Contact IS NULL
ORDER BY tblAdvertisers.Advertiser;

-- Access: qryNullAdvAltContacts
CREATE OR REPLACE VIEW `qryNullAdvAltContacts` AS
SELECT tblAdvertisers.AlternateContact,
       tblAdvertisers.AdvertiserID,
       tblAdvertisers.Advertiser
FROM tblAdvertisers
WHERE tblAdvertisers.AlternateContact IS NULL
ORDER BY tblAdvertisers.Advertiser;

-- Access: qryDeleteAdvertiser
CREATE OR REPLACE VIEW `qryDeleteAdvertiser` AS
SELECT tblAdvertisers.*,
       tblAdvertisers.AdvertiserID AS AdvertiserID2
FROM tblAdvertisers
WHERE tblAdvertisers.AdvertiserID = 11107;

-- Access: QryGtoP
CREATE OR REPLACE VIEW `QryGtoP` AS
SELECT 'P' AS NewCategory
FROM tblAdvertisers
WHERE tblAdvertisers.AdvertiserOrLead = 'G';

-- Access: Query3
CREATE OR REPLACE VIEW `Query3` AS
SELECT COUNT(tblAdvertisers.AdvertiserID) AS AdvertiserCount
FROM tblAdvertisers;

-- Access: Query3a
CREATE OR REPLACE VIEW `Query3a` AS
SELECT tblAdvertisers.AdvertiserID,
       tblAdvertisers.AcctExecID,
       tblAdvertisers.AdvertiserOrLead
FROM tblAdvertisers
WHERE tblAdvertisers.AdvertiserOrLead = 'P'
ORDER BY tblAdvertisers.AcctExecID;

-- Access: Query5
CREATE OR REPLACE VIEW `Query5` AS
SELECT tblAdvContacts.ContactID,
       tblAdvContacts.AdvertiserID,
       tblAdvContacts.FName,
       tblAdvContacts.LName,
       tblAdvContacts.`Primary`,
       tblAdvContacts.PrimarySeq,
       tblAdvContacts.ContactLevel,
       tblAdvContacts.ContactLevelSeq
FROM tblAdvContacts
WHERE tblAdvContacts.AdvertiserID = 8318;

-- Access: dltComment
CREATE OR REPLACE VIEW `dltComment` AS
SELECT tblComments.*
FROM tblComments
WHERE tblComments.CommentID = 88853;

-- Access: updFillBlankInitialDate
-- Note: This was an UPDATE query in Access - converted to SELECT view
CREATE OR REPLACE VIEW `updFillBlankInitialDate` AS
SELECT tblAdvertisers.AdvertiserID,
       '2006-06-01' AS DefaultInitialDate
FROM tblAdvertisers
WHERE tblAdvertisers.InitialContactDate IS NULL;

-- Access: updLeadsToProspects
-- Note: This was an UPDATE query in Access - converted to SELECT view
CREATE OR REPLACE VIEW `updLeadsToProspects` AS
SELECT tblAdvertisers.AdvertiserID,
       'P' AS NewCategory
FROM tblAdvertisers
WHERE tblAdvertisers.AdvertiserOrLead = 'L';

-- ----------------------------------------------------------------------------
-- Contact Creation Helper Views
-- ----------------------------------------------------------------------------

-- Access: qryCreateTblAdvContacts
CREATE OR REPLACE VIEW `qryCreateTblAdvContacts` AS
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
WHERE LOCATE(' ', tblAdvertisers.Contact) IS NOT NULL
  AND LOCATE(' ', tblAdvertisers.Contact) > 0;

-- Access: qryCreateTblAdvContactsAlt
CREATE OR REPLACE VIEW `qryCreateTblAdvContactsAlt` AS
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
WHERE LOCATE(' ', tblAdvertisers.AlternateContact) IS NOT NULL
  AND LOCATE(' ', tblAdvertisers.AlternateContact) > 0;

-- Access: qryCreateTblAdvContactsxxx
CREATE OR REPLACE VIEW `qryCreateTblAdvContactsxxx` AS
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
       NULL AS PrimarySeq,
       NULL AS PhCell,
       LOCATE(' ', tblAdvertisers.Contact) AS FirstBlank
FROM tblAdvertisers
WHERE LOCATE(' ', tblAdvertisers.Contact) IS NOT NULL
  AND LOCATE(' ', tblAdvertisers.Contact) > 0;

-- ----------------------------------------------------------------------------
-- Multi-table Views (no query dependencies)
-- ----------------------------------------------------------------------------

-- Access: qryContactList
CREATE OR REPLACE VIEW `qryContactList` AS
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

-- Access: qryProspectList
CREATE OR REPLACE VIEW `qryProspectList` AS
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

-- Access: Query1
CREATE OR REPLACE VIEW `Query1` AS
SELECT tblAdvertisers.Advertiser,
       tblAdvertisers.Contact,
       tblAdvertisers.Phone,
       tblAcctExecs.AcctExec,
       tblAdvertisers.LastContactDate,
       tblAdvertisers.AdvertiserOrLead,
       tblAdvertisers.AdvertiserID
FROM tblAdvertisers
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
WHERE tblAdvertisers.AdvertiserOrLead = 'A'
  AND tblAdvertisers.Advertiser LIKE 'bellai%'
ORDER BY tblAdvertisers.Advertiser;

-- Access: qryChronologicalComments
CREATE OR REPLACE VIEW `qryChronologicalComments` AS
SELECT tblAdvertisers.Advertiser,
       tblAcctExecs.AcctExec,
       tblComments.CommentDate,
       tblComments.CommentTime,
       tblComments.Comment
FROM tblComments
JOIN tblAdvertisers ON tblComments.AdvertiserID = tblAdvertisers.AdvertiserID
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
ORDER BY tblComments.CommentDate;

-- Access: qryChronologicalCommentsTemplate
CREATE OR REPLACE VIEW `qryChronologicalCommentsTemplate` AS
SELECT CONCAT(tblAdvertisers.Advertiser, ' ', tblAdvertisers.Street) AS AdvertiserStreet,
       tblAcctExecs.AcctExec,
       tblComments.CommentDate,
       tblComments.CommentTime,
       tblComments.Comment
FROM tblComments
JOIN tblAdvertisers ON tblComments.AdvertiserID = tblAdvertisers.AdvertiserID
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
ORDER BY CONCAT(tblAdvertisers.Advertiser, ' ', tblAdvertisers.Street);

-- Access: updOpenProspectsToCold
-- Note: This was an UPDATE query in Access - converted to SELECT view
CREATE OR REPLACE VIEW `updOpenProspectsToCold` AS
SELECT tblAdvertisers.AdvertiserID,
       'Cold' AS NewStatus
FROM tblAdvertisers
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
WHERE tblAdvertisers.AcctExecID = 11;

-- ----------------------------------------------------------------------------
-- Street/Suite Concatenation Views
-- ----------------------------------------------------------------------------

-- Access: qry_Concat_StreetAndSuite
CREATE OR REPLACE VIEW `qry_Concat_StreetAndSuite` AS
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

-- Access: qry_Concat_StreetAndSuite_2
-- Note: References tblAdvContacts01 table
CREATE OR REPLACE VIEW `qry_Concat_StreetAndSuite_2` AS
SELECT 'tblAdvContacts01' AS TableName,
       tblAdvContacts01.ContactID,
       tblAdvContacts01.AdvertiserID,
       tblAdvertisers.Advertiser,
       tblAcctExecs.AcctExec,
       tblAdvertisers.AdvertiserOrLead,
       tblAdvContacts01.Street,
       tblAdvContacts01.Suite,
       CONCAT(tblAdvContacts01.Street, ', Suite ', tblAdvContacts01.Suite) AS CombinedAddress
FROM tblAdvContacts01
JOIN tblAdvertisers ON tblAdvContacts01.AdvertiserID = tblAdvertisers.AdvertiserID
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
WHERE tblAdvContacts01.Street NOT LIKE CONCAT('%', tblAdvContacts01.Suite, '%')
  AND tblAdvContacts01.Suite IS NOT NULL;

-- Access: qry_Concat_StreetAndSuite_3
-- Note: References tblAdvContacts02 table
CREATE OR REPLACE VIEW `qry_Concat_StreetAndSuite_3` AS
SELECT 'tblAdvContacts02' AS TableName,
       tblAdvContacts02.ContactID,
       tblAdvContacts02.AdvertiserID,
       tblAdvertisers.Advertiser,
       tblAcctExecs.AcctExec,
       tblAdvertisers.AdvertiserOrLead,
       tblAdvContacts02.Street,
       tblAdvContacts02.Suite,
       CONCAT(tblAdvContacts02.Street, ', Suite ', tblAdvContacts02.Suite) AS CombinedAddress
FROM tblAdvContacts02
JOIN tblAdvertisers ON tblAdvContacts02.AdvertiserID = tblAdvertisers.AdvertiserID
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
WHERE tblAdvContacts02.Street NOT LIKE CONCAT('%', tblAdvContacts02.Suite, '%')
  AND tblAdvContacts02.Suite IS NOT NULL;

-- Access: qry_Concat_StreetAndSuite_4
-- Note: References tblAdvContacts1 table
CREATE OR REPLACE VIEW `qry_Concat_StreetAndSuite_4` AS
SELECT 'tblAdvContacts1' AS TableName,
       tblAdvContacts1.ContactID,
       tblAdvContacts1.AdvertiserID,
       tblAdvertisers.Advertiser,
       tblAcctExecs.AcctExec,
       tblAdvertisers.AdvertiserOrLead,
       tblAdvContacts1.Street,
       tblAdvContacts1.Suite,
       CONCAT(tblAdvContacts1.Street, ', Suite ', tblAdvContacts1.Suite) AS CombinedAddress
FROM tblAdvContacts1
JOIN tblAdvertisers ON tblAdvContacts1.AdvertiserID = tblAdvertisers.AdvertiserID
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
WHERE tblAdvContacts1.Street NOT LIKE CONCAT('%', tblAdvContacts1.Suite, '%')
  AND tblAdvContacts1.Suite IS NOT NULL;

-- Access: qry_Concat_StreetAndSuite_5
CREATE OR REPLACE VIEW `qry_Concat_StreetAndSuite_5` AS
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

-- Access: qry_Concat_StreetAndSuite_6
CREATE OR REPLACE VIEW `qry_Concat_StreetAndSuite_6` AS
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

-- ----------------------------------------------------------------------------
-- Duplicate Finding Views
-- ----------------------------------------------------------------------------

-- Access: Find duplicates for tblAdvertisers
CREATE OR REPLACE VIEW `Find duplicates for tblAdvertisers` AS
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

-- Access: Find duplicates for tblAdvertisers1
CREATE OR REPLACE VIEW `Find duplicates for tblAdvertisers1` AS
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

-- ----------------------------------------------------------------------------
-- Excel Import Views (require ExcelAdvertisers/ExcelLeads tables)
-- ----------------------------------------------------------------------------

-- Access: ConvertAdvertisers
CREATE OR REPLACE VIEW `ConvertAdvertisers` AS
SELECT ExcelAdvertisers.Advertiser,
       ExcelAdvertisers.AcctExecID,
       ExcelAdvertisers.AdvertiserOrLead
FROM ExcelAdvertisers;

-- Access: ConvertLeads
CREATE OR REPLACE VIEW `ConvertLeads` AS
SELECT ExcelLeads.Advertiser,
       ExcelLeads.AcctExecID,
       ExcelLeads.AdvertiserOrLead
FROM ExcelLeads;

-- ============================================================================
-- LEVEL 1: Views that depend on LEVEL 0 queries
-- ============================================================================

-- Access: qryRptAdvertisers
-- Depends on: qryCommentDateLatest
CREATE OR REPLACE VIEW `qryRptAdvertisers` AS
SELECT tblAdvertisers.Advertiser,
       tblAdvertisers.Contact,
       tblAcctExecs.AcctExec,
       tblAdvertisers.LastContactDate,
       tblAdvertisers.AdvertiserOrLead,
       tblAdvertisers.InitialContactDate,
       tblAdvertisers.ContractExpires,
       tblAdvertisers.ContractType,
       qryCommentDateLatest.`Last Contact`,
       tblAdvertisers.Temp
FROM tblAdvertisers
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
LEFT JOIN qryCommentDateLatest ON tblAdvertisers.AdvertiserID = qryCommentDateLatest.AdvertiserID
ORDER BY tblAdvertisers.Advertiser;

-- Access: qryListTemplate
-- Depends on: qryCommentDateLatest
CREATE OR REPLACE VIEW `qryListTemplate` AS
SELECT tblAdvertisers.Advertiser,
       tblAdvertisers.Contact,
       tblAdvertisers.Phone,
       tblAdvertisers.AdvertiserOrLead,
       tblAcctExecs.AcctExec,
       tblAdvertisers.InitialContactDate,
       qryCommentDateLatest.`Last Contact`,
       tblAdvertisers.Temp,
       tblAdvertisers.Active,
       tblAdvertisers.AdvertiserID
FROM tblAdvertisers
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
LEFT JOIN qryCommentDateLatest ON tblAdvertisers.AdvertiserID = qryCommentDateLatest.AdvertiserID;

-- Access: qryAdvertiserList
-- Depends on: qryAdvPrimaryContacts, qryCommentDateLatest
CREATE OR REPLACE VIEW `qryAdvertiserList` AS
SELECT tblAdvertisers.AdvertiserID,
       tblAdvertisers.Advertiser,
       CONCAT(qryAdvPrimaryContacts.FName, ' ', qryAdvPrimaryContacts.LName) AS PrimaryContact,
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
       qryCommentDateLatest.`Last Contact`,
       tblAdvertisers.Temp,
       tblAdvertisers.Active,
       tblBusinessType.BusinessType
FROM tblAdvertisers
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
LEFT JOIN qryCommentDateLatest ON tblAdvertisers.AdvertiserID = qryCommentDateLatest.AdvertiserID
LEFT JOIN tblBusinessType ON tblAdvertisers.BusinessType = tblBusinessType.BusinessTypeID
LEFT JOIN qryAdvPrimaryContacts ON tblAdvertisers.AdvertiserID = qryAdvPrimaryContacts.AdvertiserID
ORDER BY tblAdvertisers.Advertiser;

-- Access: qryTestAdvSelection
-- Depends on: qryAdvPrimaryContacts, qryCommentDateLatest
CREATE OR REPLACE VIEW `qryTestAdvSelection` AS
SELECT tblAdvertisers.AdvertiserID,
       tblAdvertisers.Advertiser,
       CONCAT(qryAdvPrimaryContacts.FName, ' ', qryAdvPrimaryContacts.LName) AS PrimaryContact,
       tblAdvertisers.Street,
       tblAdvertisers.City,
       tblAdvertisers.St,
       tblAdvertisers.Zip,
       tblAdvertisers.Phone,
       tblAdvertisers.PhExt,
       tblAdvertisers.Email,
       tblAcctExecs.AcctExec,
       tblAdvertisers.AdvertiserOrLead,
       tblAdvertisers.ContractDate,
       tblAdvertisers.InitialContactDate,
       qryCommentDateLatest.`Last Contact`,
       tblAdvertisers.Temp,
       tblAdvertisers.Active,
       tblBusinessType.BusinessType
FROM tblAdvertisers
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
LEFT JOIN qryCommentDateLatest ON tblAdvertisers.AdvertiserID = qryCommentDateLatest.AdvertiserID
LEFT JOIN tblBusinessType ON tblAdvertisers.BusinessType = tblBusinessType.BusinessTypeID
LEFT JOIN qryAdvPrimaryContacts ON tblAdvertisers.AdvertiserID = qryAdvPrimaryContacts.AdvertiserID
ORDER BY tblAdvertisers.Advertiser;

-- ============================================================================
-- LEVEL 2: Views that depend on LEVEL 1 queries
-- ============================================================================

-- Access: qryAdvertiserListExport
-- Depends on: qryAdvertiserList
CREATE OR REPLACE VIEW `qryAdvertiserListExport` AS
SELECT qryAdvertiserList.AdvertiserID,
       qryAdvertiserList.Advertiser,
       qryAdvertiserList.Street,
       qryAdvertiserList.City,
       qryAdvertiserList.St,
       qryAdvertiserList.Zip,
       qryAdvertiserList.Phone,
       qryAdvertiserList.PhExt,
       qryAdvertiserList.Email,
       qryAdvertiserList.`Account Manager`,
       qryAdvertiserList.Category,
       qryAdvertiserList.`Contract Expires`,
       qryAdvertiserList.`Initial Contact`,
       qryAdvertiserList.`Last Contact`,
       qryAdvertiserList.Temp,
       qryAdvertiserList.Active,
       qryAdvertiserList.BusinessType,
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
FROM qryAdvertiserList
JOIN tblAdvContacts ON qryAdvertiserList.AdvertiserID = tblAdvContacts.AdvertiserID
ORDER BY qryAdvertiserList.Advertiser;

-- Access: qryAdvertiserListExportPrimary
-- Depends on: qryAdvertiserList
CREATE OR REPLACE VIEW `qryAdvertiserListExportPrimary` AS
SELECT qryAdvertiserList.AdvertiserID,
       qryAdvertiserList.Advertiser,
       qryAdvertiserList.Street,
       qryAdvertiserList.City,
       qryAdvertiserList.St,
       qryAdvertiserList.Zip,
       qryAdvertiserList.Phone,
       qryAdvertiserList.PhExt,
       qryAdvertiserList.Email,
       qryAdvertiserList.`Account Manager`,
       qryAdvertiserList.Category,
       qryAdvertiserList.`Contract Expires`,
       qryAdvertiserList.`Initial Contact`,
       qryAdvertiserList.`Last Contact`,
       qryAdvertiserList.Temp,
       qryAdvertiserList.Active,
       qryAdvertiserList.BusinessType,
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
FROM qryAdvertiserList
JOIN tblAdvContacts ON qryAdvertiserList.AdvertiserID = tblAdvContacts.AdvertiserID
WHERE tblAdvContacts.`Primary` = 'Y'
ORDER BY qryAdvertiserList.Advertiser;

-- ============================================================================
-- PLACEHOLDER VIEWS for incomplete/empty Access queries
-- These had empty SELECT lists in Access - created as placeholders
-- ============================================================================

-- Access: qry_CONCAT_Merge_5and6
-- Note: Original Access query was empty/incomplete
CREATE OR REPLACE VIEW `qry_CONCAT_Merge_5and6` AS
SELECT NULL AS AdvertiserID
WHERE 1=0;

-- Access: qry_CONCAT_MergeAllSuiteChanges
-- Note: Original Access query was empty/incomplete
CREATE OR REPLACE VIEW `qry_CONCAT_MergeAllSuiteChanges` AS
SELECT NULL AS AdvertiserID
WHERE 1=0;

-- Access: qry_CONCAT_FullPop
-- Note: Original Access query was empty/incomplete
CREATE OR REPLACE VIEW `qry_CONCAT_FullPop` AS
SELECT NULL AS placeholder
WHERE 1=0;

-- Access: ~sq_ffrmContactLevels
-- Note: Form subquery - empty in Access
CREATE OR REPLACE VIEW `~sq_ffrmContactLevels` AS
SELECT DISTINCT *
FROM tblContactLevels;

-- Access: ~sq_ffrmPrefix
-- Note: Form subquery - empty in Access
CREATE OR REPLACE VIEW `~sq_ffrmPrefix` AS
SELECT DISTINCT *
FROM tblPrefix;

-- Access: ~sq_ffrmSecurity
-- Note: Form subquery - empty in Access
CREATE OR REPLACE VIEW `~sq_ffrmSecurity` AS
SELECT DISTINCT *
FROM tblSecurity;

-- Access: ~sq_ffrmPPAMaxQty
-- Note: Form subquery - empty in Access
CREATE OR REPLACE VIEW `~sq_ffrmPPAMaxQty` AS
SELECT DISTINCT *
FROM tblPPAMaxQty;

-- Access: ~sq_ffrmProductCategories
-- Note: Form subquery - empty in Access
CREATE OR REPLACE VIEW `~sq_ffrmProductCategories` AS
SELECT DISTINCT *
FROM tblProductCategories;

-- Access: ~sq_ffrmSuffix
-- Note: Form subquery - empty in Access
CREATE OR REPLACE VIEW `~sq_ffrmSuffix` AS
SELECT DISTINCT *
FROM tblSuffix;

-- ============================================================================
-- LEVEL 3: Views that depend on placeholder views
-- ============================================================================

-- Access: qry_CONCAT_NotInMergeButNeedResearch
-- Depends on: qry_CONCAT_Merge_5and6
CREATE OR REPLACE VIEW `qry_CONCAT_NotInMergeButNeedResearch` AS
SELECT 'tblAdvertisers' AS TableName,
       '' AS ContactID,
       tblAdvertisers.AdvertiserID,
       tblAdvertisers.Advertiser,
       tblAcctExecs.AcctExec,
       tblAdvertisers.AdvertiserOrLead,
       tblAdvertisers.Street,
       tblAdvertisers.Suite,
       'REVIEW : Already had suite in address.' AS ReviewNote
FROM tblAdvertisers
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
WHERE tblAdvertisers.AdvertiserID NOT IN (
    SELECT AdvertiserID FROM `qry_CONCAT_Merge_5and6` WHERE AdvertiserID IS NOT NULL
)
AND tblAdvertisers.Suite IS NOT NULL;

-- Access: qry_CONCAT_NotInSuitePop
-- Depends on: qry_CONCAT_MergeAllSuiteChanges
CREATE OR REPLACE VIEW `qry_CONCAT_NotInSuitePop` AS
SELECT 'tblAdvertisers' AS TableName,
       '' AS ContactID,
       tblAdvertisers.AdvertiserID,
       tblAdvertisers.Advertiser,
       tblAcctExecs.AcctExec,
       tblAdvertisers.AdvertiserOrLead,
       tblAdvertisers.Street,
       tblAdvertisers.Suite,
       'No Change needed.' AS ReviewNote
FROM tblAdvertisers
JOIN tblAcctExecs ON tblAdvertisers.AcctExecID = tblAcctExecs.AcctExecID
WHERE tblAdvertisers.AdvertiserID NOT IN (
    SELECT AdvertiserID FROM `qry_CONCAT_MergeAllSuiteChanges` WHERE AdvertiserID IS NOT NULL
);

-- ============================================================================
-- STORED PROCEDURES
-- These replace Access queries that referenced form controls
-- ============================================================================

DELIMITER //

-- Access: qrySfrmComments
-- Original referenced: Forms!frmAdvertisers!AdvertiserID
DROP PROCEDURE IF EXISTS `qrySfrmComments`//
CREATE PROCEDURE `qrySfrmComments`(IN p_AdvertiserID INT)
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
END//

-- Access: Query2
-- Original referenced: Forms!frmAdvertisers!cmbAcctExecID
DROP PROCEDURE IF EXISTS `Query2`//
CREATE PROCEDURE `Query2`(IN p_AcctExecID INT)
BEGIN
    SELECT tblAdvertisers.AcctExecID,
           tblAdvertisers.AdvertiserOrLead
    FROM tblAdvertisers
    WHERE tblAdvertisers.AcctExecID = p_AcctExecID
      AND tblAdvertisers.AdvertiserOrLead = 'L';
END//

-- Access: Query4
-- Original referenced: Forms!frmAdvertisers!cmbAdvertiserOrLead
DROP PROCEDURE IF EXISTS `Query4`//
CREATE PROCEDURE `Query4`(IN p_AdvertiserOrLead VARCHAR(10))
BEGIN
    SELECT tblPPAMaxQty.AdvertiserOrLead,
           tblPPAMaxQty.MaxQty
    FROM tblPPAMaxQty
    WHERE tblPPAMaxQty.AdvertiserOrLead = p_AdvertiserOrLead;
END//

-- Access: QryTest
-- Original referenced: Forms!frmAdvertiserAndContactLists!txtSelectAdvertiser
DROP PROCEDURE IF EXISTS `QryTest`//
CREATE PROCEDURE `QryTest`(IN p_SearchTerm VARCHAR(255))
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
END//

DELIMITER ;

-- ============================================================================
-- SUMMARY OF CONVERSIONS
-- ============================================================================
-- 
-- Total Views Created: 56
-- Total Stored Procedures Created: 4
-- 
-- DEPENDENCY ORDER:
--   Level 0: Base views (no query dependencies)
--     - qryAcctExecs, qryCmbAcctExecID, qryCmbAE, qryCmbAdvertiserOrLead
--     - qryCmbAllAorP, qryCmbBusinessType, qryCmbContactLevel, qryContractType
--     - qryPrefix, qrySuffix, qryStPostalCd, qryCmdPrimaryContact
--     - qryCommentDateLatest, qryAdvPrimaryContacts, qryAdvertisers
--     - qrySelectAdvertiser, qrySfrmAdvContacts, qryAlternateContact
--     - qryContactLvlClient, qryPrimaryContact, qryNullAdvContacts
--     - qryNullAdvAltContacts, qryDeleteAdvertiser, QryGtoP, Query3, Query3a
--     - Query5, dltComment, updFillBlankInitialDate, updLeadsToProspects
--     - qryCreateTblAdvContacts, qryCreateTblAdvContactsAlt, qryCreateTblAdvContactsxxx
--     - qryContactList, qryProspectList, Query1, qryChronologicalComments
--     - qryChronologicalCommentsTemplate, updOpenProspectsToCold
--     - qry_Concat_StreetAndSuite, qry_Concat_StreetAndSuite_2 through _6
--     - Find duplicates for tblAdvertisers, Find duplicates for tblAdvertisers1
--     - ConvertAdvertisers, ConvertLeads
--     - ~sq_ffrm* (form subqueries)
--     - qry_CONCAT_Merge_5and6, qry_CONCAT_MergeAllSuiteChanges, qry_CONCAT_FullPop
-- 
--   Level 1: (depends on Level 0)
--     - qryRptAdvertisers (depends on qryCommentDateLatest)
--     - qryListTemplate (depends on qryCommentDateLatest)
--     - qryAdvertiserList (depends on qryAdvPrimaryContacts, qryCommentDateLatest)
--     - qryTestAdvSelection (depends on qryAdvPrimaryContacts, qryCommentDateLatest)
-- 
--   Level 2: (depends on Level 1)
--     - qryAdvertiserListExport (depends on qryAdvertiserList)
--     - qryAdvertiserListExportPrimary (depends on qryAdvertiserList)
-- 
--   Level 3: (depends on placeholders)
--     - qry_CONCAT_NotInMergeButNeedResearch (depends on qry_CONCAT_Merge_5and6)
--     - qry_CONCAT_NotInSuitePop (depends on qry_CONCAT_MergeAllSuiteChanges)
-- 
-- STORED PROCEDURES (form-referenced queries):
--     - qrySfrmComments(p_AdvertiserID)
--     - Query2(p_AcctExecID)
--     - Query4(p_AdvertiserOrLead)
--     - QryTest(p_SearchTerm)
-- 
-- ============================================================================
