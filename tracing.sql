/* Sample of Tracing Algorithm
	Takes user_input of a CLNT_ID and then:
		1. Grabs all the group members of that user input CLNT_ID
		2. Grabs the local head of that user input CLNT_ID
		3. Grabs the global head of the user input CLNT_ID
		4. Grabs all the 'sister' entities that are in the same global group of the user input CLNT_ID
		5. 'Traces' up 1 level by all economic relationships using data that have an ownership percentage >0%
*/

CREATE VOLATILE TABLE Base AS (
	SELECT DISTINCT --grab all local group members of a particular CLNT_ID as local group head
		Primary_ID AS CLNT_ID
		,Linked_ID AS Head_CLNT_ID
		,Link_Start_Date
		,'Local Group' AS DATASOURCE
	FROM EntDBO.Master_Client_Links --Enterprise data warehouse table with all client relationships
	WHERE 
		Primary_ID_Type = 1 --CLNT_ID
		AND Associated_ID IN (SELECT CLNT_ID FROM USER_INPUT)
		AND Link_End_Date IS NULL --Active links
		AND Link_Source_Id = 'Local Group DB'

	UNION

	SELECT DISTINCT --grab the local group head for a particular CLNT_ID
		Primary_ID AS CLNT_ID
		,Linked_ID AS Head_CLNT_ID
		,Link_Start_Date
		,'Local Group' AS DATASOURCE
	FROM EntDBO.Master_Client_Links --Enterprise data warehouse table with all client relationships
	WHERE 
		Primary_ID_Type = 1 --CLNT_ID
		AND Primary_ID IN (SELECT CLNT_ID FROM USER_INPUT)
		AND Link_End_Date IS NULL
		AND Link_Source_Id = 'Local Group DB'

	UNION

	SELECT DISTINCT --grab all entities with the same global group head
		Primary_ID AS CLNT_ID
		,Linked_ID AS Head_CLNT_ID
		,Link_Start_Date
		,'Global Group' AS DATASOURCE
	FROM EntDBO.Master_Client_Links --Enterprise data warehouse table with all client relationships
	WHERE 
		Linked_ID IN (
			SELECT DISTINCT Linked_ID AS CLNT_ID --Grab the UHC of the
			FROM EntDBO.Master_Client_Links --Enterprise data warehouse table with all client relationships
			WHERE 
				Primary_ID IN (SELECT CLNT_ID FROM USER_INPUT)
				AND Linked_ID_Type = 1 --CLNT_ID
				AND Link_End_Date IS NULL
				AND Link_Source_Id = 'Global Group DB'
		AND Link_End_Date IS NULL
		AND Link_Source_Id = 'Global Group DB'

) WITH DATA PRIMARY INDEX (CLNT_ID) ON COMMIT PRESERVE ROWS;

CREATE VOLATILE TABLE L0 AS (
	SELECT
		Base.CLNT_ID As Level_0
		,CLNT.Entity_Name AS Level_0_Name
		,Base.Head_CLNT_ID As Head_ID
		,CLNT2.Head_Entity_Name AS Head_Name
		,Base.Link_Start_Date
		,Base.Datasource
	FROM Base

	LEFT JOIN ( --Get Entity Name and ID
		SELECT
			B1.CLNT_ID
			,B1.Company_ID --Specific share registry identifier for 3rd party share registries
			,B2.Entity_Name

		FROM EntDBO.CLNT_ID_TABLE B1 --Enterprise table that keeps all IDs matched with 3rd party data
		INNER JOIN EntDBO.Client_Name B2 ON B1.CLNT_ID --Dimension table that keeps all names matched with CLNT_ID

	WHERE
		B1.Clnt_Id_Status = 'Active' --only active CLNT_IDs
		AND B2.Client_Name_Effective_End_Date > CURRENT_DATE --Bitemporal model --only active names
		AND B2.Client_name_Record_End_Date > CURRENT_DATE --Bitemporal model -- latest record
	) CLNT ON Base.CLNT_ID = CLNT.CLNT_ID

	LEFT JOIN ( --Get Head Entity Name and ID
		SELECT
			B1.CLNT_ID
			,B1.Company_ID --Specific share registry identifier for 3rd party share registries
			,B2.Entity_Name

		FROM EntDBO.CLNT_ID_TABLE B1 --Enterprise table that keeps all IDs matched with 3rd party data
		INNER JOIN EntDBO.Client_Name B2 ON B1.CLNT_ID --Dimension table that keeps all names matched with CLNT_ID

	WHERE
		B1.Clnt_Id_Status = 'Active' --only active CLNT_IDs
		AND B2.Client_Name_Effective_End_Date > CURRENT_DATE --Bitemporal model --only active names
		AND B2.Client_name_Record_End_Date > CURRENT_DATE --Bitemporal model -- latest record
	) CLNT2 ON Base.Head_CLNT_ID = CLNT2.CLNT_ID
) WITH DATA PRIMARY INDEX (Level_0_Name) ON COMMIT PRESERVE ROWS;

---Going Up---
CREATE VOLATILE TABLE L0_1 AS (
	SELECT DISTINCT
		L0.Level_0
		,L0.Level_0_ID_Type
		,L0.Level_0_Name
		,CLNT_LNK.Linked_ID AS Level_1
		,CLNT_LNK.Linked_ID AS Level_1_ID_Type
		,CASE
			WHEN CLNT_LNK.Linked_ID_Type = 1 THEN CLNT.Entity_Name --If local ID, then name
			WHEN CLNT_LNK.Linked_ID_Type = 2 THEN SHARE.Organisation_Name --If global ID, then use share registry name
			ELSE NULL
		END AS Level_1_Name
		,CASE 
			WHEN CLNT_LNK.Ownership_Pct > 0 THEN CLNT_LNK.Ownership_Pct * 100
			WHEN CLNT_LNK.Beneficial_Pct > 0 THEN CLNT_LNK.Beneficial_Pct * 100
			WHEN CLNT_LNK.Control_Pct > 0 THEN CLNT_LNK.Control_Pct * 100
			ELSE 0
		END AS Ownership_Percentage
		,CLNT_LNK.Link_Start_Date
		,CLNT_LNK.Link_Source_Id AS DATASOURCE
	FROM L0

	LEFT JOIN (
		SELECT *
		FROM EntDBO.Master_Client_Links
		WHERE
			Link_Source_Id = 'Share registry'
			AND (Link_End_Date > CURRENT DATE OR Link_End_Date IS NULL)
			AND (Ownership_Pct > 0 OR Beneficial_Pct > 0 OR Control_Pct > 0)
	) CLNT_LNK
	ON L0.Level_0 = CLNT_LNK.Primary_ID 
	AND Level_0_ID_Type = CLNT_LNK.Primary_ID_Type

	LEFT JOIN ( --local group data
		SELECT
			B1.CLNT_ID
			,B1.Company_ID --Specific share registry identifier for 3rd party share registries
			,B2.Entity_Name
		FROM EntDBO.CLNT_ID_TABLE B1 --Enterprise table that keeps all IDs matched with 3rd party data
		INNER JOIN EntDBO.Client_Name B2 ON B1.CLNT_ID --Dimension table that keeps all names matched with CLNT_ID

	WHERE
		B1.Clnt_Id_Status = 'Active' --only active CLNT_IDs
		AND B2.Client_Name_Effective_End_Date > CURRENT_DATE --Bitemporal model --only active names
		AND B2.Client_name_Record_End_Date > CURRENT_DATE --Bitemporal model -- latest record
	) CLNT ON CLNT.CLNT_ID = CLNT_LNK.Linked_ID

	LEFT JOIN ( --Global share registry data
		SELECT
			Organisation_ID
			,Organisation_Name
		FROM EntDBO.Share_Registry --3rd party share registry data
		WHERE 
			Organisation_ID = 'Active'
			AND Organisation_Name_Effective_End_Date > CURRENT_DATE --Bitemporal model --only active names
			AND Organisation_Name_Record_End_Date > CURRENT_DATE --Bitemporal model -- latest record
	) SHARE
	ON SHARE.Organisation_ID = CLNT_LNK.Linked_ID

) WITH DATA PRIMARY INDEX (Level_0) ON COMMIT PRESERVE ROWS;

SELECT * FROM L0_1;