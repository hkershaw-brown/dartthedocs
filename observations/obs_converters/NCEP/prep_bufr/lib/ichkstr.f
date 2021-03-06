	FUNCTION ICHKSTR(STR,CHR,N)

C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM:    ICHKSTR
C   PRGMMR: ATOR             ORG: NP12       DATE: 2005-11-29
C
C ABSTRACT: THIS FUNCTION COMPARES A SPECIFIED NUMBER OF CHARACTERS
C   FROM AN INPUT CHARACTER ARRAY AGAINST THE SAME NUMBER OF CHARACTERS
C   FROM AN INPUT CHARACTER STRING AND DETERMINES WHETHER THE TWO ARE
C   EQUIVALENT.  THE CHARACTER ARRAY IS ASSUMED TO BE IN ASCII, WHEREAS
C   THE CHARACTER STRING IS ASSUMED TO BE IN THE NATIVE CHARACTER SET
C   (I.E. ASCII OR EBCDIC) OF THE LOCAL MACHINE.
C
C PROGRAM HISTORY LOG:
C 2005-11-29  J. ATOR    -- ORIGINAL AUTHOR
C DART $Id$
C
C USAGE:    ICHKSTR (STR, CHR, N)
C   INPUT ARGUMENT LIST:
C     STR      - CHARACTER*(*): N-CHARACTER STRING IN ASCII OR EBCDIC,
C                DEPENDING ON THE NATIVE MACHINE
C     CHR      - CHARACTER*1: ARRAY OF N CHARACTERS IN ASCII
C     N        - INTEGER: NUMBER OF CHARACTERS TO BE COMPARED
C
C   OUTPUT ARGUMENT LIST:
C     ICHKSTR  - INTEGER: RETURN VALUE:
C                  0 = STR(1:N) AND (CHR(I),I=1,N) ARE EQUIVALENT
C                  1 = STR(1:N) AND (CHR(I),I=1,N) ARE NOT EQUIVALENT
C
C REMARKS:
C    THIS ROUTINE CALLS:        CHRTRNA
C    THIS ROUTINE IS CALLED BY: CRBMG    OPENBF   RDMSGB   RDMSGW
C                               READERME
C                               Normally not called by any application
C                               programs. 
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 77
C   MACHINE:  PORTABLE TO ALL PLATFORMS
C
C$$$

	CHARACTER*(*) STR

	CHARACTER*80  CSTR
	CHARACTER*1   CHR(N)

C-----------------------------------------------------------------------
C-----------------------------------------------------------------------

C	Copy CHR into CSTR and, if necessary, convert the latter
C	to EBCDIC (i.e. if the local machine uses EBCDIC) so that
C	the subsequent comparison will always be valid.

	CALL CHRTRNA(CSTR,CHR,N)

C	Compare CSTR to STR.

	IF(CSTR(1:N).EQ.STR(1:N)) THEN
	    ICHKSTR = 0
	ELSE
	    ICHKSTR = 1
	ENDIF	

	RETURN
	END
