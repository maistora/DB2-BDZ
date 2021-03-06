set schema FN71168 @
-- 1 -- DROP PROCEDURE DISTANCE_CALC @
-- 2 -- DROP PROCEDURE SET_DISTANCE_CALC @
-- 3 -- DROP PROCEDURE CARD_RED_VALUE @
-- 4 -- DROP PROCEDURE LOOP_CARDS_RED_VALUE @
-- 5 -- DROP PROCEDURE CATEGORY @
-- 6 -- DROP PROCEDURE SET_CATEGORY @
-- 7 -- DROP PROCEDURE TICKET_PRICE @
-- 8 -- DROP  PROCEDURE PRICE_LOOP @
-----------------------------------------------------------
-- 1 --  PRESMQTANE RAZSTOQNIETO PO DADEN MARSHRUT
-----------------------------------------------------------
CREATE PROCEDURE DISTANCE_CALC 
	(IN ROUTE_ID_P CHAR(6))
	LANGUAGE SQL
	BEGIN
		DECLARE DIST INT;
			SELECT SUM(DISTANCE) INTO DIST
			FROM SUB_ROUTE
			WHERE ROUTE_PID = ROUTE_ID_P; 
		UPDATE ROUTE 
		SET DISTANCE = DIST WHERE ROUTE_ID = ROUTE_ID_P;
	END @
	
--DROP PROCEDURE DISTANCE_CALC @

----------------------------------------------------------
-- 2 --  POSTAVQNE NA DISTANCIQ ZA VSEKI ZAPIS V ROUTE TABLICATA
--------------------------------------------------------
CREATE PROCEDURE SET_DISTANCE_CALC()
	LANGUAGE SQL
	BEGIN
		DECLARE AT_END INT DEFAULT 0;
		DECLARE R1 CHAR(6);
		DECLARE NOT_FOUND CONDITION FOR SQLSTATE '02000';
		DECLARE ROUTE_CURSOR CURSOR FOR 
			SELECT ROUTE_ID
			FROM ROUTE;
		DECLARE CONTINUE HANDLER FOR NOT_FOUND SET AT_END = 1;
		OPEN ROUTE_CURSOR;
		L1: LOOP
			FETCH ROUTE_CURSOR INTO R1;
			IF AT_END = 1 THEN LEAVE L1;
			ELSE CALL FN71168.DISTANCE_CALC(R1);
			END IF;
		END LOOP;
		
	END @

--DROP PROCEDURE SET_DISTANCE_CALC @
	

----------------------------------------------------------
-- 3 -- IZBIRANE NA STOINOST ZA NAMALENIE PO ZADADENO CARD ID V TABLICA CARDS
----------------------------------------------------------
CREATE PROCEDURE CARD_RED_VALUE (IN CARD_ID1 CHAR(7), IN CARD_ID2 CHAR(7))
	LANGUAGE SQL
	BEGIN
		DECLARE RED_VAL1 DECIMAL(8,2);
		DECLARE RED_VAL2 DECIMAL(8,2);
		
		SET RED_VAL1 = 	(	SELECT RED_VALUE 
							FROM SUBS_CARDS
							WHERE SUB_CARD = CARD_ID1
						);
					
		SET RED_VAL2 = 	(	SELECT RED_VALUE 
							FROM REDUNDANCY_CARDS
							WHERE RED_CARD = CARD_ID2
						);
						
		IF RED_VAL1 IS NOT NULL THEN 
			UPDATE CARDS SET RED_VALUE = RED_VAL1 WHERE ID_AB_REF = CARD_ID1;
		ELSE IF RED_VAL2 IS NOT NULL THEN 
			UPDATE CARDS SET RED_VALUE = RED_VAL2 WHERE ID_ZL_REF = CARD_ID2;
			END IF;
		END IF;
		
	END @
	
--DROP PROCEDURE CARD_RED_VALUE @

--------------------------------------------------------------------
-- 4 -- set all redundancy values in table CARDS
--------------------------------------------------------------------
CREATE PROCEDURE LOOP_CARDS_RED_VALUE () 
	LANGUAGE SQL
	BEGIN
		DECLARE ID1 CHAR(7);
		DECLARE ID2 CHAR(7);
		DECLARE END_ERR INT DEFAULT 0;
		DECLARE NOT_FOUND CONDITION FOR SQLSTATE '02000';
		DECLARE CARD_ID_CURSOR CURSOR FOR 
			SELECT ID_AB_REF, ID_ZL_REF
			FROM CARDS;
		DECLARE CONTINUE HANDLER FOR NOT_FOUND SET END_ERR = 1;
		OPEN CARD_ID_CURSOR;
		L1: LOOP
			FETCH CARD_ID_CURSOR INTO ID1, ID2;
			IF END_ERR = 1 THEN LEAVE L1;
			ELSE CALL FN71168.CARD_RED_VALUE(ID1, ID2);
			END IF;
		END LOOP;	
		
	END @
	
--DROP PROCEDURE LOOP_CARDS_RED_VALUE @
 

--------------------------------------------------------
-- 5 -- PROCEDURA ZA VYVEJDANE NA KATEGORIQTA NA VLAKA V BILETA
--------------------------------------------------------
CREATE PROCEDURE CATEGORY 
	(IN TRAIN_ID_P CHAR(4))
	LANGUAGE SQL
	BEGIN
		DECLARE CAT VARCHAR(20);
		
		SET CAT = (	SELECT TRAIN_CATEGORY
					FROM TRAIN 
					WHERE TRAIN_ID = TRAIN_ID_P);
		
		UPDATE TICKET 
		SET TRAIN_CATEGORY = CAT WHERE TRAIN_REF = TRAIN_ID_P;
	END @
	
--DROP PROCEDURE CATEGORY @

----------------------------------------------------------
--6 -- POSTAVQNE NA KATEGORIQ ZA VSEKI ZAPIS V TICKET TABLICATA
--------------------------------------------------------
CREATE PROCEDURE SET_CATEGORY()
	LANGUAGE SQL
	BEGIN
		DECLARE AT_END INT DEFAULT 0;
		DECLARE TR_ID VARCHAR(20);
		DECLARE NOT_FOUND CONDITION FOR SQLSTATE '02000';
		DECLARE TICKET_CURSOR CURSOR FOR 
			SELECT TRAIN_REF --TUK
			FROM TICKET;
		DECLARE CONTINUE HANDLER FOR NOT_FOUND SET AT_END = 1;
		
		OPEN TICKET_CURSOR;
		
		L1: LOOP
			FETCH TICKET_CURSOR INTO TR_ID;
			IF AT_END = 1 THEN LEAVE L1;
			ELSE CALL FN71168.CATEGORY(TR_ID);
			END IF;
		END LOOP;
	END @
--DROP PROCEDURE SET_CATEGORY @

-----------------------------------------------------------
-- 7 --  PRESMQTANE CENATA NA BILETA
-- po dadeni route, class, card, ticket_id i rezervaciq I PO VID VLAK!
-----------------------------------------------------------
CREATE PROCEDURE TICKET_PRICE
	(IN MY_ROUTE_ID CHAR(6), IN MY_CLASS_TYPE VARCHAR(20),
	 IN MY_CARD_ID CHAR(7), IN RES_SEAT VARCHAR(4), 
	 IN ID_TICKET CHAR(7), IN TR_CAT VARCHAR(20))
	LANGUAGE SQL
	P1: BEGIN
	
			DECLARE RT_DIST INT;
			DECLARE CL_VALUE DECIMAL(8,2);
			DECLARE RED_VAL DECIMAL(8,2);

			DECLARE CAT_FST DECIMAL(8,2);
			DECLARE CAT_EXP DECIMAL(8,2);
			DECLARE CAT_ORD DECIMAL(8,2);
			
			SET CAT_FST = 0.5;
			SET CAT_EXP = 0.8;
			SET CAT_ORD = 0;
			
			
			IF ID_TICKET IS NOT NULL THEN 
			
				IF MY_ROUTE_ID IS NOT NULL THEN
					SET RT_DIST = (	SELECT DISTANCE
									FROM ROUTE
									WHERE ROUTE_ID = MY_ROUTE_ID);
									
					IF MY_CLASS_TYPE IS NOT NULL THEN
						SET CL_VALUE = (	SELECT CLASS_VALUE
											FROM CLASS
											WHERE CLASS_TYPE = MY_CLASS_TYPE);
					
						
							IF RT_DIST IS NOT NULL AND CL_VALUE IS NOT NULL THEN 
								UPDATE TICKET
								SET PRICE = RT_DIST * CL_VALUE WHERE TICKET_ID = ID_TICKET;
								
								P2 : BEGIN
									-- TRQBVAT STOJNOSTI V TABLICA CARDS ZA RED_VALUE -> DRUGA PROCEDURA
									
									
									IF MY_CARD_ID IS NOT NULL THEN 
										SET RED_VAL = (		SELECT RED_VALUE
															FROM CARDS
															WHERE CARD_ID = MY_CARD_ID);
									END IF;
									
									IF RED_VAL IS NOT NULL THEN
										UPDATE TICKET
										SET PRICE = PRICE * RED_VAL WHERE TICKET_ID = ID_TICKET;
									END IF;
									
									IF RES_SEAT IS NOT NULL THEN
										UPDATE TICKET
										SET PRICE = PRICE + 0.50  WHERE TICKET_ID = ID_TICKET;
									END IF;
									
									IF TR_CAT IS NOT NULL THEN
										IF TR_CAT = 'FAST' THEN 
											UPDATE TICKET SET PRICE = PRICE + CAT_FST;
											ELSE IF TR_CAT = 'EXPRESS' THEN
												UPDATE TICKET SET PRICE = PRICE + CAT_EXP;
											ELSE IF TR_CAT = 'ORDINARY' THEN
												UPDATE TICKET SET PRICE = PRICE + CAT_ORD;
											END IF;
										END IF;
									END IF;
								END IF;
								END P2;
							END IF; 
						END IF;
					END IF;
				END IF;
			--END IF;
		END P1 @

--DROP PROCEDURE TICKET_PRICE @

--------------------------------------------------------------------
-- 8 -- zadavane ceni na vsichki bileti
--------------------------------------------------------------------
CREATE PROCEDURE PRICE_LOOP () 
	LANGUAGE SQL 
	BEGIN
		DECLARE RT_ID CHAR(6);
		DECLARE CL_RF VARCHAR(20);
		DECLARE ID_CD CHAR(7);
		DECLARE RS_ST VARCHAR(4);
		DECLARE TCKT CHAR(7);
		DECLARE TR_CT VARCHAR(20);
	
		DECLARE AT_END INT DEFAULT 0;
		
		DECLARE NOT_FOUND CONDITION FOR SQLSTATE '02000';
		DECLARE MY_CURSOR CURSOR FOR 
			SELECT ROUTE_REF, CLASS_REF, ID_CARD, RESERVED_SEAT, TICKET_ID, TRAIN_CATEGORY
			FROM TICKET;
		DECLARE CONTINUE HANDLER FOR NOT_FOUND SET AT_END = 1;
		
		OPEN MY_CURSOR;
		
		L1: LOOP
			FETCH MY_CURSOR INTO RT_ID, CL_RF, ID_CD, RS_ST, TCKT, TR_CT;
			IF AT_END = 1 THEN LEAVE L1;
			ELSE CALL FN71168.TICKET_PRICE(RT_ID, CL_RF, ID_CD, RS_ST, TCKT, TR_CT);
			END IF;
		END LOOP;
	END @
	
--DROP  PROCEDURE PRICE_LOOP @


-----------------------------------------------------------
--PRESMQTANE PRODYLJITELNOSTTA NA PYTUVANETO PO DADEN MARSHRUT

   --- NE STAAAAAA!!!!!! ------
   -- NE BACA 
-----------------------------------------------------------
CREATE PROCEDURE DURATION_CALC 
	(IN ROUTE_ID_P CHAR(6))
	LANGUAGE SQL
	BEGIN
		DECLARE DUR INT;
		
		SET DUR = (	SELECT (HOUR(DEPARTURE_TIME) - HOUR(ARRIVING_TIME))/60.00 AS T
					FROM TIME_TABLE);
		
		UPDATE TIME_TABLE 
		SET DURATION = DUR;
	END @

--DROP PROCEDURE DISTANCE_CALC @

