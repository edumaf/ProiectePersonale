ACCEPT p_id_carte NUMBER PROMPT 'Dati id carte:';

CREATE OR REPLACE PACKAGE procesare_tabele
IS
    PROCEDURE inserare_date;
    PROCEDURE upd_detalii_carti;
END procesare_tabele;
/

CREATE OR REPLACE PACKAGE BODY procesare_tabele
IS
    PROCEDURE inserare_date
    IS
    BEGIN
            -----------------------------------------------------------------------------INSERARE DATE IN TABELA BIBLIOTECA
    
        INSERT INTO biblioteca VALUES(10,'Biblioteca Judeteana Gheorghe Asachi','Iasi');
        INSERT INTO biblioteca VALUES(12,'Biblioteca Octavian Goga', 'Cluj');
        
        ---------------------------------------------------------------------------------INSERARE DATE IN TABELA DETALII_BIBLIOTECA
        
        INSERT INTO detalii_biblioteca VALUES( 
            'bibl_gheorghe_asachi@yahoo.com','0332110044','L-V 9-20 S 9-15',
            (SELECT id_biblioteca FROM biblioteca WHERE nume_biblioteca='Biblioteca Judeteana Gheorghe Asachi')
        );
        
        INSERT INTO detalii_biblioteca VALUES( 
            'bibl_octaviangoga@yahoo.com','0264430323','L-V 08:00-20:00',
            (SELECT id_biblioteca FROM biblioteca WHERE nume_biblioteca='Biblioteca Octavian Goga')
        );
        
        ----------------------------------------------------------------------------------INSERARE DATE IN TABELA ABONAT
        
        ------------------------------BIBLIOTECA GHEORGHE ASACHI
        INSERT INTO abonat VALUES(
            115,'Prodan Oana Elena', '074234598','oana_prodan@yahoo.com',
            (SELECT id_biblioteca FROM biblioteca WHERE nume_biblioteca='Biblioteca Judeteana Gheorghe Asachi')
        );
        
        INSERT INTO abonat VALUES(
            107, 'Maftei Eduard', '0772341289','maftei_eduard@yahoo.com',
            (SELECT id_biblioteca FROM biblioteca WHERE nume_biblioteca='Biblioteca Judeteana Gheorghe Asachi')
        );
        
        ------------------------------BIBLIOTECA OCTAVIAN GOGA
        INSERT INTO abonat VALUES(
            201, 'Bejan Ionut', '074325339','bej_ion299@gmail.com',
            (SELECT id_biblioteca FROM biblioteca WHERE nume_biblioteca='Biblioteca Octavian Goga')
        );
        
        INSERT INTO abonat VALUES(
            225, 'Chirica Mihaela', '071125339','mchirica@yahoo.com',
            (SELECT id_biblioteca FROM biblioteca WHERE nume_biblioteca='Biblioteca Octavian Goga')
        );
        
        ---------------------------------------------------------------------------------INSERARE TABELA ABONAMENTE
        INSERT INTO abonament VALUES(
            1000, 'student',TO_DATE('01.10.2018','DD.MM.YYYY'),TO_DATE('30.09.2022','DD.MM.YYYY'),115
        );
        
        INSERT INTO abonament VALUES(
            1043, 'student',TO_DATE('15.12.2020','DD.MM.YYYY'),TO_DATE('30.09.2022','DD.MM.YYYY'),107
        );
        
        INSERT INTO abonament VALUES(
            2001, 'standard',TO_DATE('14.08.2021','DD.MM.YYYY'),TO_DATE('14.08.2022','DD.MM.YYYY'),201
        );
        
        INSERT INTO abonament VALUES(
            2025, 'elev',TO_DATE('10.01.2022','DD.MM.YYYY'),TO_DATE('14.09.2023','DD.MM.YYYY'),225
        );
        
        ---------------------------------------------------------------------------------INSERARE DATE TABELA CARTI
        
        -----------------BIBLIOTECA GHEORGHE ASACHI
        INSERT INTO carti VALUES(
            20, (SELECT id_biblioteca FROM biblioteca WHERE nume_biblioteca='Biblioteca Judeteana Gheorghe Asachi'),
            'romance','Confess',2017
        );
        
        INSERT INTO carti VALUES(
            21, (SELECT id_biblioteca FROM biblioteca WHERE nume_biblioteca='Biblioteca Judeteana Gheorghe Asachi'),
            'drept','Teoria generala a dreptului',2020
        );
        
        INSERT INTO carti VALUES(
            23, (SELECT id_biblioteca FROM biblioteca WHERE nume_biblioteca='Biblioteca Judeteana Gheorghe Asachi'),
            'fizica','Fizica F1+F2',2018
        );
        
        ----------------BIBLIOTECA OCTAVIAN GOGA
        INSERT INTO carti VALUES(
            30,(SELECT id_biblioteca FROM biblioteca WHERE nume_biblioteca='Biblioteca Octavian Goga'),
            'medicina','Teste pentru asistentii medicali',2016
        );
        
        INSERT INTO carti VALUES(
            31, (SELECT id_biblioteca FROM biblioteca WHERE nume_biblioteca='Biblioteca Octavian Goga'),
            'romance','Fangirl',2016
        );
        
        INSERT INTO carti VALUES(
            32, (SELECT id_biblioteca FROM biblioteca WHERE nume_biblioteca='Biblioteca Octavian Goga'),
            'drept','Tratat de procedura penala',2017
        );
        
        -----------------------------------------------------------------------INSERARE DATE IN TABELA AUTORI
        INSERT INTO autori VALUES(1, 'Cooleen Hoover');
        INSERT INTO autori VALUES(2, 'Costica Voicu');
        INSERT INTO autori VALUES(3, 'Constantin Mitrache');
        INSERT INTO autori VALUES(4, 'Violeta Neagu');
        INSERT INTO autori VALUES(5, 'Rainbow Rowell');
        
        
        -----------------------------------------------------------------------INSERARE DATE IN TABELA CARTI_AUTORI
        INSERT INTO carti_autori VALUES(1,20);
        INSERT INTO carti_autori VALUES(2,21);
        INSERT INTO carti_autori VALUES(2,32);
        INSERT INTO carti_autori VALUES(3,23);
        INSERT INTO carti_autori VALUES(4,30);
        INSERT INTO carti_autori VALUES(5,31);
        
        ------------------------------------------------------------------------INSERARE DATE IN TABELA DETALII_CARTI
        INSERT INTO detalii_carti(status, id_carte) VALUES('disponibila',20);
        INSERT INTO detalii_carti(status, id_carte) VALUES('disponibila',21);
        INSERT INTO detalii_carti VALUES('imprumutata', TO_DATE('01.03.2021','DD.MM.YYYY'), 23, 107, TO_DATE('17.06.2022','DD.MM.YYYY'));
        INSERT INTO detalii_carti VALUES('imprumutata', TO_DATE('05.03.2022','DD.MM.YYYY'), 30, 201, TO_DATE('29.05.2022','DD.MM.YYYY'));
    END inserare_date;
    
    PROCEDURE upd_detalii_carti
    IS
    BEGIN
        UPDATE detalii_carti
        SET status = 'disponibila', data_rezervare=NULL, data_returnare=NULL, id_abonat=''
        WHERE id_carte = &p_id_carte;
    END upd_detalii_carti;
END procesare_tabele;
/

BEGIN
    procesare_tabele.inserare_date;
END;
/

BEGIN
    procesare_tabele.upd_detalii_carti;
END;