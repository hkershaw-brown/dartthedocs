      SUBROUTINE WRITCA(LUNXX,MSGT,MSGL)

C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM:    WRITCA
C   PRGMMR: J. ATOR          ORG: NP12       DATE: 2004-08-18
C
C ABSTRACT: THIS SUBROUTINE IS CONSIDERED OBSOLETE AND MAY BE REMOVED
C   FROM THE BUFR ARCHIVE LIBRARY IN A FUTURE VERSION.  IT NOW SIMPLY
C   CALLS BUFR ARCHIVE LIBRARY SUBROUTINE CMPMSG TO TOGGLE ON MESSAGE
C   COMPRESSION, FOLLOWED BY A CALL TO WRITSA (SEE WRITSA DOCBLOCK).
C   THIS SUBROUTINE USES THE SAME INPUT AND OUTPUT PARAMETERS AS WRITSA.
C
C PROGRAM HISTORY LOG:
C 2004-08-18  J. ATOR    -- ORIGINAL AUTHOR; BASED UPON WRITSA
C 2005-03-09  J. ATOR    -- MARKED AS OBSOLETE AND ADDED PRINT
C                           NOTIFICATION
C DART $Id$
C
C USAGE:    CALL WRITCA (LUNXX, MSGT, MSGL)
C   INPUT ARGUMENT LIST:
C     LUNXX    - INTEGER: ABSOLUTE VALUE IS FORTRAN LOGICAL UNIT NUMBER
C                FOR BUFR FILE {IF LUNXX IS LESS THAN ZERO, THEN ANY
C                CURRENT MESSAGE IN MEMORY WILL BE FORCIBLY FLUSHED TO
C                ABS(LUNXX) AND TO ARRAY MSGT}
C
C   OUTPUT ARGUMENT LIST:
C     MSGT     - INTEGER: *-WORD PACKED BINARY ARRAY CONTAINING BUFR
C                MESSAGE (FIRST MSGL WORDS FILLED)
C     MSGL     - INTEGER: NUMBER OF WORDS FILLED IN MSGT
C                       0 = no message was returned
C
C REMARKS:
C    THIS ROUTINE CALLS:        CMPMSG   WRITSA
C    THIS ROUTINE IS CALLED BY: None
C                               Normally called only by application
C                               programs.
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 77
C   MACHINE:  PORTABLE TO ALL PLATFORMS
C
C$$$

      COMMON /QUIET / IPRT

      DATA IFIRST/0/

      SAVE IFIRST

C-----------------------------------------------------------------------
C-----------------------------------------------------------------------

      IF(IFIRST.EQ.0) THEN
         IF(IPRT.GE.0) THEN
      PRINT*
      PRINT*,'+++++++++++++++++BUFR ARCHIVE LIBRARY++++++++++++++++++++'
      PRINT 101
101   FORMAT(' BUFRLIB: WRITCA - THIS SUBROUTINE IS NOW OBSOLETE; ',
     . 'USE SUBROUTINES CMPMSG AND WRITSA INSTEAD')
      PRINT*,'+++++++++++++++++BUFR ARCHIVE LIBRARY++++++++++++++++++++'
      PRINT*
         ENDIF
         IFIRST = 1
      ENDIF

      CALL CMPMSG('Y')

      CALL WRITSA(LUNXX,MSGT,MSGL)

      RETURN
      END
