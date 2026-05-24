--
-- PostgreSQL database dump
--

\restrict eEmXGXhov308j7UPBoqTxM283ieXAnlSmaeh9I17rND0Mh9XpLAr2n0dMSgqg2K

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

-- Started on 2026-01-18 16:08:54

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 918 (class 1247 OID 25128)
-- Name: rola_enum; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.rola_enum AS ENUM (
    'klient',
    'admin',
    'pracownik'
);


ALTER TYPE public.rola_enum OWNER TO postgres;

--
-- TOC entry 921 (class 1247 OID 25136)
-- Name: status_enum; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.status_enum AS ENUM (
    'zaplanowana',
    'w toku',
    'zakończona',
    'odwołana'
);


ALTER TYPE public.status_enum OWNER TO postgres;

--
-- TOC entry 252 (class 1255 OID 25145)
-- Name: aktualizuj_klienta(integer, character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.aktualizuj_klienta(IN p_id integer, IN p_imie character varying, IN p_nazwisko character varying, IN p_email character varying, IN p_haslo character varying, IN p_rola character varying)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_rows_affected int;
BEGIN
   
    IF trim(p_imie) = '' OR trim(p_nazwisko) = '' OR trim(p_email) = '' OR trim(p_haslo) = '' THEN
        RAISE EXCEPTION 'Wszystkie pola są wymagane!';
    END IF;

    IF p_email !~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$' THEN
        RAISE EXCEPTION 'Adres email "%" ma nieprawidłowy format!', p_email;
    END IF;

    IF p_imie !~* '^[a-ząćęłńóśźż\s]+$' THEN
        RAISE EXCEPTION 'Imię "%" zawiera niedozwolone znaki!', p_imie;
    END IF;

    IF p_nazwisko !~* '^[a-ząćęłńóśźż\s\-]+$' THEN
        RAISE EXCEPTION 'Nazwisko "%" zawiera niedozwolone znaki!', p_nazwisko;
    END IF;

    
    UPDATE klienci 
    SET imie = p_imie, 
        nazwisko = p_nazwisko, 
        email = p_email, 
        haslo = p_haslo, 
        rola = p_rola::rola_enum,
        czy_aktywny = TRUE
    WHERE id_klienta = p_id;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    IF v_rows_affected = 0 THEN
        RAISE EXCEPTION 'Nie znaleziono klienta o ID %.', p_id;
    END IF;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Adres email % jest już zajęty przez innego użytkownika!', p_email;

    WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'Nieprawidłowa rola "%"! Dozwolone wartości: klient, admin, pracownik.', p_rola;
    
    WHEN string_data_right_truncation THEN
         RAISE EXCEPTION 'Wprowadzone dane są zbyt długie.';
    
END;
$_$;


ALTER PROCEDURE public.aktualizuj_klienta(IN p_id integer, IN p_imie character varying, IN p_nazwisko character varying, IN p_email character varying, IN p_haslo character varying, IN p_rola character varying) OWNER TO postgres;

--
-- TOC entry 253 (class 1255 OID 25146)
-- Name: aktualizuj_moje_konto(integer, text, character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.aktualizuj_moje_konto(IN p_id integer, IN p_rola text, IN p_imie character varying, IN p_nazwisko character varying, IN p_email character varying, IN p_stare_haslo character varying, IN p_nowe_haslo character varying)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_obecne_haslo VARCHAR;
    v_istniejacy_id INT;
BEGIN

    IF trim(p_imie) = '' OR trim(p_nazwisko) = '' OR trim(p_email) = '' THEN
        RAISE EXCEPTION 'Imię, nazwisko i email są wymagane!';
    END IF;

    IF p_email !~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$' THEN
        RAISE EXCEPTION 'Adres email "%" ma nieprawidłowy format!', p_email;
    END IF;

   
    SELECT haslo INTO v_obecne_haslo FROM klienci WHERE id_klienta = p_id;

    IF v_obecne_haslo IS NULL OR v_obecne_haslo != p_stare_haslo THEN
        RAISE EXCEPTION 'Podano nieprawidłowe obecne hasło! Zmiany odrzucone.';
    END IF;

    
    SELECT id_klienta INTO v_istniejacy_id 
    FROM klienci 
    WHERE email = p_email AND id_klienta != p_id;

    IF v_istniejacy_id IS NOT NULL THEN
        RAISE EXCEPTION 'Adres email % jest już zajęty przez innego użytkownika.', p_email;
    END IF;

    
    UPDATE klienci 
    SET imie = p_imie, 
        nazwisko = p_nazwisko, 
        email = p_email,
        haslo = CASE WHEN trim(p_nowe_haslo) != '' THEN p_nowe_haslo ELSE haslo END
    WHERE id_klienta = p_id;

EXCEPTION
    WHEN string_data_right_truncation THEN
         RAISE EXCEPTION 'Wprowadzone dane są zbyt długie.';
END;
$_$;


ALTER PROCEDURE public.aktualizuj_moje_konto(IN p_id integer, IN p_rola text, IN p_imie character varying, IN p_nazwisko character varying, IN p_email character varying, IN p_stare_haslo character varying, IN p_nowe_haslo character varying) OWNER TO postgres;

--
-- TOC entry 254 (class 1255 OID 25147)
-- Name: aktualizuj_pracownika(integer, character varying, character varying, character varying, character varying, numeric, integer[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.aktualizuj_pracownika(IN p_id integer, IN p_imie character varying, IN p_nazwisko character varying, IN p_pesel character varying, IN p_telefon character varying, IN p_zarobki numeric, IN p_specjalizacje integer[])
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_rows_affected int;
    v_spec_id int;
    v_czy_spec_aktywna boolean;
BEGIN
   
    IF trim(p_imie) = '' OR trim(p_nazwisko) = '' OR trim(p_pesel) = '' OR trim(p_telefon) = '' THEN
        RAISE EXCEPTION 'Wszystkie pola są wymagane!';
    END IF;

    IF p_imie !~* '^[a-ząćęłńóśźż\s]+$' THEN
        RAISE EXCEPTION 'Imię "%" zawiera niedozwolone znaki!', p_imie;
    END IF;

    IF p_nazwisko !~* '^[a-ząćęłńóśźż\s\-]+$' THEN
        RAISE EXCEPTION 'Nazwisko "%" zawiera niedozwolone znaki!', p_nazwisko;
    END IF;

    IF p_pesel !~* '^[0-9]{11}$' THEN
        RAISE EXCEPTION 'PESEL "%" jest nieprawidłowy (musi mieć 11 cyfr)!', p_pesel;
    END IF;

    IF p_telefon !~* '^[0-9 ]+$' THEN
        RAISE EXCEPTION 'Numer telefonu może zawierać tylko cyfry i spacje!';
    END IF;

    IF p_zarobki <= 0 THEN
        RAISE EXCEPTION 'Zarobki muszą być dodatnie!';
    END IF;
	
    
    UPDATE pracownicy 
    SET imie = p_imie, 
        nazwisko = p_nazwisko, 
        pesel = p_pesel,
        numer_telefonu = p_telefon, 
        zarobki_PLN = p_zarobki,
        czy_aktywny = TRUE
    WHERE id_pracownika = p_id;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    IF v_rows_affected = 0 THEN
        RAISE EXCEPTION 'Nie znaleziono pracownika o ID %.', p_id;
    END IF;

    
    DELETE FROM pracownicy_specjalizacje WHERE id_pracownika = p_id;

    IF p_specjalizacje IS NOT NULL AND array_length(p_specjalizacje, 1) > 0 THEN
        
        FOREACH v_spec_id IN ARRAY p_specjalizacje
        LOOP
            SELECT czy_aktywna INTO v_czy_spec_aktywna FROM specjalizacje WHERE id_specjalizacji = v_spec_id;
            
            IF NOT FOUND OR v_czy_spec_aktywna = FALSE THEN
                 RAISE EXCEPTION 'Wybrana specjalizacja (ID: %) jest nieprawidłowa lub nieaktywna.', v_spec_id;
            END IF;
        END LOOP;

        INSERT INTO pracownicy_specjalizacje (id_pracownika, id_specjalizacji)
        SELECT p_id, unnest(p_specjalizacje);
    END IF;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Podany PESEL jest już przypisany do innego pracownika!';
    WHEN string_data_right_truncation THEN
         RAISE EXCEPTION 'Wprowadzone dane są zbyt długie.';
    
END;
$_$;


ALTER PROCEDURE public.aktualizuj_pracownika(IN p_id integer, IN p_imie character varying, IN p_nazwisko character varying, IN p_pesel character varying, IN p_telefon character varying, IN p_zarobki numeric, IN p_specjalizacje integer[]) OWNER TO postgres;

--
-- TOC entry 255 (class 1255 OID 25148)
-- Name: aktualizuj_specjalizacje(integer, character varying, integer[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.aktualizuj_specjalizacje(IN p_id integer, IN p_nazwa character varying, IN p_uslugi integer[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_rows_affected int;
BEGIN
    IF trim(p_nazwa) = '' THEN
        RAISE EXCEPTION 'Nazwa specjalizacji jest wymagana!';
    END IF;

    
    IF EXISTS (
        SELECT 1 FROM specjalizacje 
        WHERE LOWER(nazwa) = LOWER(p_nazwa) 
        AND id_specjalizacji != p_id
    ) THEN
        RAISE EXCEPTION 'Specjalizacja o nazwie "%" już istnieje!', p_nazwa;
    END IF;

    UPDATE specjalizacje 
    SET nazwa = p_nazwa,
        czy_aktywna = TRUE
    WHERE id_specjalizacji = p_id;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    IF v_rows_affected = 0 THEN
        RAISE EXCEPTION 'Nie znaleziono specjalizacji o ID %.', p_id;
    END IF;

    
    DELETE FROM uslugi_specjalizacje WHERE id_specjalizacji = p_id;

    IF p_uslugi IS NOT NULL AND array_length(p_uslugi, 1) > 0 THEN
        INSERT INTO uslugi_specjalizacje (id_uslugi, id_specjalizacji)
        SELECT unnest(p_uslugi), p_id;
    END IF;

EXCEPTION
    WHEN string_data_right_truncation THEN
         RAISE EXCEPTION 'Nazwa specjalizacji jest zbyt długa.';
    
END;
$$;


ALTER PROCEDURE public.aktualizuj_specjalizacje(IN p_id integer, IN p_nazwa character varying, IN p_uslugi integer[]) OWNER TO postgres;

--
-- TOC entry 256 (class 1255 OID 25149)
-- Name: aktualizuj_usluge(integer, character varying, integer, numeric, integer[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.aktualizuj_usluge(IN p_id integer, IN p_nazwa character varying, IN p_czas integer, IN p_cena numeric, IN p_specjalizacje integer[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_rows_affected int;
BEGIN
    IF trim(p_nazwa) = '' THEN
        RAISE EXCEPTION 'Nazwa usługi jest wymagana!';
    END IF;

    IF p_czas <= 0 THEN
        RAISE EXCEPTION 'Czas trwania musi być dodatni!';
    END IF;

    IF p_cena < 0 THEN
        RAISE EXCEPTION 'Cena nie może być ujemna!';
    END IF;

    UPDATE uslugi 
    SET nazwa = p_nazwa, 
        czas_trwania = p_czas, 
        cena = p_cena,
        czy_aktywna = TRUE 
    WHERE id_uslugi = p_id;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    IF v_rows_affected = 0 THEN
        RAISE EXCEPTION 'Nie znaleziono usługi o ID %.', p_id;
    END IF;

   
    DELETE FROM uslugi_specjalizacje WHERE id_uslugi = p_id;

    IF p_specjalizacje IS NOT NULL AND array_length(p_specjalizacje, 1) > 0 THEN
        INSERT INTO uslugi_specjalizacje (id_uslugi, id_specjalizacji)
        SELECT p_id, unnest(p_specjalizacje);
    END IF;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Usługa o nazwie "%" już istnieje!', p_nazwa;
    WHEN string_data_right_truncation THEN
         RAISE EXCEPTION 'Nazwa usługi jest zbyt długa.';
    
END;
$$;


ALTER PROCEDURE public.aktualizuj_usluge(IN p_id integer, IN p_nazwa character varying, IN p_czas integer, IN p_cena numeric, IN p_specjalizacje integer[]) OWNER TO postgres;

--
-- TOC entry 257 (class 1255 OID 25150)
-- Name: aktualizuj_wizyte(integer, timestamp without time zone, character varying, integer, integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.aktualizuj_wizyte(IN p_id integer, IN p_data timestamp without time zone, IN p_status character varying, IN p_id_klienta integer, IN p_id_pracownika integer, IN p_id_uslugi integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_stara_data timestamp;
    v_czy_aktywny BOOLEAN;
    v_wymagane_specjalizacje INT;
    v_posiadane_specjalizacje INT;
    v_godzina TIME;
    v_dzien_tygodnia INT;
BEGIN

    IF p_data IS NULL THEN RAISE EXCEPTION 'Data wizyty jest wymagana!'; END IF;
    IF trim(p_status) = '' THEN RAISE EXCEPTION 'Status wizyty jest wymagany!'; END IF;

    SELECT data_wizyty INTO v_stara_data FROM wizyty WHERE id_wizyty = p_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Błąd: Nie znaleziono wizyty o ID %.', p_id; END IF;

  
    IF p_data != v_stara_data AND p_data <= LOCALTIMESTAMP THEN
        RAISE EXCEPTION 'Nie można przenieść wizyty do przeszłości!';
    END IF;

    v_godzina := CAST(p_data AS TIME);
    v_dzien_tygodnia := EXTRACT(DOW FROM p_data);
    IF v_dzien_tygodnia = 0 THEN RAISE EXCEPTION 'Salon jest nieczynny w niedziele!'; END IF;
    IF v_godzina < '09:00:00' OR v_godzina >= '18:00:00' THEN RAISE EXCEPTION 'Salon jest czynny w godzinach 09:00 - 18:00!'; END IF;

   
    SELECT czy_aktywny INTO v_czy_aktywny FROM klienci WHERE id_klienta = p_id_klienta;
    IF v_czy_aktywny = FALSE THEN RAISE EXCEPTION 'Wybrany klient jest nieaktywny!'; END IF;

    SELECT czy_aktywny INTO v_czy_aktywny FROM pracownicy WHERE id_pracownika = p_id_pracownika;
    IF v_czy_aktywny = FALSE THEN RAISE EXCEPTION 'Wybrany pracownik jest nieaktywny!'; END IF;

    SELECT czy_aktywna INTO v_czy_aktywny FROM uslugi WHERE id_uslugi = p_id_uslugi;
    IF v_czy_aktywny = FALSE THEN RAISE EXCEPTION 'Wybrana usługa jest nieaktywna!'; END IF;

 
    SELECT COUNT(*) INTO v_wymagane_specjalizacje FROM uslugi_specjalizacje WHERE id_uslugi = p_id_uslugi;
    IF v_wymagane_specjalizacje > 0 THEN
        SELECT COUNT(*) INTO v_posiadane_specjalizacje
        FROM pracownicy_specjalizacje ps
        JOIN uslugi_specjalizacje us ON ps.id_specjalizacji = us.id_specjalizacji
        WHERE ps.id_pracownika = p_id_pracownika AND us.id_uslugi = p_id_uslugi;

        IF v_posiadane_specjalizacje = 0 THEN
            RAISE EXCEPTION 'Ten pracownik nie posiada żadnej wymaganej specjalizacji do tej usługi (ID Pracownika: %, ID Usługi: %)!', p_id_pracownika, p_id_uslugi;
        END IF;
    END IF;

    IF EXISTS (
        SELECT 1 FROM pracownicy_wizyty pw 
        JOIN wizyty w ON pw.id_wizyty = w.id_wizyty 
        WHERE pw.id_pracownika = p_id_pracownika 
          AND w.data_wizyty = p_data 
          AND w.status != 'odwołana'
          AND w.id_wizyty != p_id
    ) THEN
        RAISE EXCEPTION 'Ten pracownik ma już inną wizytę w tym terminie!';
    END IF;

    
    UPDATE wizyty SET data_wizyty = p_data, status = p_status::status_enum WHERE id_wizyty = p_id;
    UPDATE klienci_wizyty SET id_klienta = p_id_klienta WHERE id_wizyty = p_id;
    UPDATE pracownicy_wizyty SET id_pracownika = p_id_pracownika WHERE id_wizyty = p_id;
    UPDATE wizyty_uslugi SET id_uslugi = p_id_uslugi WHERE id_wizyty = p_id;

EXCEPTION
    WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'Błąd: Status "%" jest nieprawidłowy!', p_status;
END;
$$;


ALTER PROCEDURE public.aktualizuj_wizyte(IN p_id integer, IN p_data timestamp without time zone, IN p_status character varying, IN p_id_klienta integer, IN p_id_pracownika integer, IN p_id_uslugi integer) OWNER TO postgres;

--
-- TOC entry 258 (class 1255 OID 25151)
-- Name: blokada_zmiany_zakonczonych(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.blokada_zmiany_zakonczonych() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Sprawdzamy: Jeśli stary status był 'zakończona', a nowy jest inny...
    IF OLD.status = 'zakończona' AND NEW.status != 'zakończona' THEN
        RAISE EXCEPTION '⛔ BŁĄD: Wizyta została już zakończona! Nie można cofnąć jej statusu.';
    END IF;
    
    IF OLD.status = 'zakończona' THEN
         RAISE EXCEPTION '⛔ BŁĄD: Nie można edytować zakończonej wizyty!';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.blokada_zmiany_zakonczonych() OWNER TO postgres;

--
-- TOC entry 259 (class 1255 OID 25152)
-- Name: dodaj_klienta(character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.dodaj_klienta(IN p_imie character varying, IN p_nazwisko character varying, IN p_email character varying, IN p_haslo character varying, IN p_rola character varying)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_istniejacy_id INT;
    v_czy_aktywny BOOLEAN;
BEGIN
    
    IF trim(p_imie) = '' OR trim(p_nazwisko) = '' OR trim(p_email) = '' OR trim(p_haslo) = '' THEN
        RAISE EXCEPTION 'Wszystkie pola są wymagane!';
    END IF;
    
    IF p_email !~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$' THEN
        RAISE EXCEPTION 'Adres email "%" ma nieprawidłowy format!', p_email;
    END IF;
    
    IF p_imie !~* '^[a-ząćęłńóśźż\s]+$' THEN
        RAISE EXCEPTION 'Imię "%" zawiera niedozwolone znaki!', p_imie;
    END IF;
    
    IF p_nazwisko !~* '^[a-ząćęłńóśźż\s\-]+$' THEN
        RAISE EXCEPTION 'Nazwisko "%" zawiera niedozwolone znaki!', p_nazwisko;
    END IF;

    
    SELECT id_klienta, czy_aktywny INTO v_istniejacy_id, v_czy_aktywny
    FROM klienci 
    WHERE email = p_email;

    IF FOUND THEN
        IF v_czy_aktywny THEN
            RAISE EXCEPTION 'Użytkownik o adresie email % już istnieje i jest aktywny!', p_email;
        ELSE
            
            UPDATE klienci 
            SET imie = p_imie,
                nazwisko = p_nazwisko,
                haslo = p_haslo,
                rola = p_rola::rola_enum,
                czy_aktywny = TRUE
            WHERE id_klienta = v_istniejacy_id;
            RETURN;
        END IF;
    END IF;

    
    INSERT INTO klienci (imie, nazwisko, email, haslo, rola, czy_aktywny)
    VALUES (p_imie, p_nazwisko, p_email, p_haslo, p_rola::rola_enum, TRUE);

EXCEPTION
    WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'Nieprawidłowa rola "%"! Dozwolone: klient, admin, pracownik.', p_rola;
    WHEN string_data_right_truncation THEN
         RAISE EXCEPTION 'Wprowadzone dane są zbyt długie.';
    
END;
$_$;


ALTER PROCEDURE public.dodaj_klienta(IN p_imie character varying, IN p_nazwisko character varying, IN p_email character varying, IN p_haslo character varying, IN p_rola character varying) OWNER TO postgres;

--
-- TOC entry 260 (class 1255 OID 25153)
-- Name: dodaj_opinie(integer, integer, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.dodaj_opinie(IN p_id_wizyty integer, IN p_ocena integer, IN p_komentarz text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_nowe_id_opinii INT;
    v_id_klienta INT;
    v_status_wizyty status_enum;
BEGIN
 
    IF trim(p_komentarz) = '' THEN
        RAISE EXCEPTION 'Treść opinii nie może być pusta!';
    END IF;

    IF p_ocena < 1 OR p_ocena > 5 THEN
        RAISE EXCEPTION 'Ocena musi być liczbą całkowitą z zakresu 1 do 5!';
    END IF;

    SELECT status INTO v_status_wizyty FROM wizyty WHERE id_wizyty = p_id_wizyty;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Wizyta o ID % nie istnieje.', p_id_wizyty;
    END IF;

    IF v_status_wizyty != 'zakończona' THEN
        RAISE EXCEPTION 'Można oceniać tylko wizyty, które mają status "zakończona"!';
    END IF;

    IF EXISTS (SELECT 1 FROM wizyty_opinie WHERE id_wizyty = p_id_wizyty) THEN
        RAISE EXCEPTION 'Ta wizyta została już oceniona!';
    END IF;

    SELECT id_klienta INTO v_id_klienta FROM klienci_wizyty WHERE id_wizyty = p_id_wizyty LIMIT 1;

    IF v_id_klienta IS NULL THEN
        RAISE EXCEPTION 'Błąd spójności danych: Do tej wizyty nie jest przypisany żaden klient.';
    END IF;

   
    INSERT INTO opinie (ocena, komentarz, created_at, czy_aktywna)
    VALUES (p_ocena, p_komentarz, NOW(), TRUE)
    RETURNING id_opinii INTO v_nowe_id_opinii;

    INSERT INTO wizyty_opinie (id_wizyty, id_opinii) 
    VALUES (p_id_wizyty, v_nowe_id_opinii);
    
    INSERT INTO klienci_opinie (id_klienta, id_opinii) 
    VALUES (v_id_klienta, v_nowe_id_opinii);

EXCEPTION
    WHEN string_data_right_truncation THEN
         RAISE EXCEPTION 'Treść komentarza jest zbyt długa.';
END;
$$;


ALTER PROCEDURE public.dodaj_opinie(IN p_id_wizyty integer, IN p_ocena integer, IN p_komentarz text) OWNER TO postgres;

--
-- TOC entry 261 (class 1255 OID 25154)
-- Name: dodaj_pracownika(character varying, character varying, character varying, character varying, numeric, integer[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.dodaj_pracownika(IN p_imie character varying, IN p_nazwisko character varying, IN p_pesel character varying, IN p_telefon character varying, IN p_zarobki numeric, IN p_specjalizacje integer[])
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_istniejacy_id INT;
    v_czy_aktywny BOOLEAN;
    v_przetwarzany_id INT;
    v_spec_id INT;
    v_czy_spec_aktywna BOOLEAN;
BEGIN
    IF trim(p_imie) = '' OR trim(p_nazwisko) = '' OR trim(p_pesel) = '' OR trim(p_telefon) = '' THEN
        RAISE EXCEPTION 'Wszystkie pola są wymagane!';
    END IF;

    IF p_imie !~* '^[a-ząćęłńóśźż\s]+$' THEN
        RAISE EXCEPTION 'Imię "%" zawiera niedozwolone znaki!', p_imie;
    END IF;

    IF p_nazwisko !~* '^[a-ząćęłńóśźż\s\-]+$' THEN
        RAISE EXCEPTION 'Nazwisko "%" zawiera niedozwolone znaki!', p_nazwisko;
    END IF;

    IF p_pesel !~* '^[0-9]{11}$' THEN
        RAISE EXCEPTION 'PESEL "%" jest nieprawidłowy (musi mieć 11 cyfr)!', p_pesel;
    END IF;

    IF p_telefon !~* '^[0-9 ]+$' THEN
        RAISE EXCEPTION 'Numer telefonu może zawierać tylko cyfry i spacje!';
    END IF;

    IF p_zarobki <= 0 THEN
        RAISE EXCEPTION 'Zarobki muszą być dodatnie!';
    END IF;

    
    SELECT id_pracownika, czy_aktywny INTO v_istniejacy_id, v_czy_aktywny
    FROM pracownicy 
    WHERE pesel = p_pesel;

    IF FOUND THEN
        IF v_czy_aktywny THEN
            RAISE EXCEPTION 'Pracownik z numerem PESEL % już istnieje!', p_pesel;
        ELSE
            
            UPDATE pracownicy
            SET imie = p_imie,
                nazwisko = p_nazwisko,
                numer_telefonu = p_telefon,
                zarobki_PLN = p_zarobki,
                czy_aktywny = TRUE
            WHERE id_pracownika = v_istniejacy_id;
            
            v_przetwarzany_id := v_istniejacy_id;
            
            
            DELETE FROM pracownicy_specjalizacje WHERE id_pracownika = v_przetwarzany_id;
        END IF;
    ELSE
        
        INSERT INTO pracownicy (imie, nazwisko, pesel, numer_telefonu, zarobki_PLN, czy_aktywny) 
        VALUES (p_imie, p_nazwisko, p_pesel, p_telefon, p_zarobki, TRUE)
        RETURNING id_pracownika INTO v_przetwarzany_id;
    END IF;

    
    IF p_specjalizacje IS NOT NULL AND array_length(p_specjalizacje, 1) > 0 THEN
        
        
        FOREACH v_spec_id IN ARRAY p_specjalizacje
        LOOP
            SELECT czy_aktywna INTO v_czy_spec_aktywna FROM specjalizacje WHERE id_specjalizacji = v_spec_id;
            IF NOT FOUND OR v_czy_spec_aktywna = FALSE THEN
                 RAISE EXCEPTION 'Wybrana specjalizacja (ID: %) jest nieprawidłowa lub nieaktywna.', v_spec_id;
            END IF;
        END LOOP;

        INSERT INTO pracownicy_specjalizacje (id_pracownika, id_specjalizacji)
        SELECT v_przetwarzany_id, unnest(p_specjalizacje);
    END IF;

EXCEPTION
    WHEN string_data_right_truncation THEN
         RAISE EXCEPTION 'Wprowadzone dane są zbyt długie.';
   
END;
$_$;


ALTER PROCEDURE public.dodaj_pracownika(IN p_imie character varying, IN p_nazwisko character varying, IN p_pesel character varying, IN p_telefon character varying, IN p_zarobki numeric, IN p_specjalizacje integer[]) OWNER TO postgres;

--
-- TOC entry 262 (class 1255 OID 25155)
-- Name: dodaj_specjalizacje(character varying, integer[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.dodaj_specjalizacje(IN p_nazwa character varying, IN p_uslugi integer[])
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_istniejace_id INT;
    v_czy_aktywna BOOLEAN;
    v_procesowane_id INT;
BEGIN
    IF trim(p_nazwa) = '' THEN
        RAISE EXCEPTION 'Nazwa specjalizacji jest wymagana!';
    END IF;

    
    IF p_nazwa !~* '^[a-ząćęłńóśźż\s\-]+$' THEN
        RAISE EXCEPTION 'Nazwa "%" zawiera niedozwolone znaki!', p_nazwa;
    END IF;

    
    SELECT id_specjalizacji, czy_aktywna INTO v_istniejace_id, v_czy_aktywna
    FROM specjalizacje 
    WHERE LOWER(nazwa) = LOWER(p_nazwa);

    IF FOUND THEN
        IF v_czy_aktywna THEN
            RAISE EXCEPTION 'Specjalizacja "%" już istnieje!', p_nazwa;
        ELSE
            
            UPDATE specjalizacje 
            SET czy_aktywna = TRUE,
                nazwa = p_nazwa
            WHERE id_specjalizacji = v_istniejace_id;
            
            v_procesowane_id := v_istniejace_id;
            
            
            DELETE FROM uslugi_specjalizacje WHERE id_specjalizacji = v_procesowane_id;
        END IF;
    ELSE
        
        INSERT INTO specjalizacje (nazwa, czy_aktywna) 
        VALUES (p_nazwa, TRUE)
        RETURNING id_specjalizacji INTO v_procesowane_id;
    END IF;

    
    IF p_uslugi IS NOT NULL AND array_length(p_uslugi, 1) > 0 THEN
        INSERT INTO uslugi_specjalizacje (id_uslugi, id_specjalizacji)
        SELECT unnest(p_uslugi), v_procesowane_id;
    END IF;

EXCEPTION
    WHEN string_data_right_truncation THEN
         RAISE EXCEPTION 'Nazwa specjalizacji jest zbyt długa.';
    
END;
$_$;


ALTER PROCEDURE public.dodaj_specjalizacje(IN p_nazwa character varying, IN p_uslugi integer[]) OWNER TO postgres;

--
-- TOC entry 263 (class 1255 OID 25156)
-- Name: dodaj_usluge(character varying, integer, numeric, integer[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.dodaj_usluge(IN p_nazwa character varying, IN p_czas integer, IN p_cena numeric, IN p_specjalizacje integer[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_istniejace_id INT;
    v_czy_aktywna BOOLEAN;
    v_procesowane_id INT;
BEGIN
   
    IF trim(p_nazwa) = '' THEN
        RAISE EXCEPTION 'Nazwa usługi jest wymagana!';
    END IF;
    
    IF p_czas <= 0 THEN
        RAISE EXCEPTION 'Czas trwania musi być dodatni (większy od 0)!';
    END IF;

    IF p_cena < 0 THEN
        RAISE EXCEPTION 'Cena nie może być ujemna!';
    END IF;

    
    SELECT id_uslugi, czy_aktywna INTO v_istniejace_id, v_czy_aktywna
    FROM uslugi 
    WHERE nazwa = p_nazwa;

    IF FOUND THEN
        IF v_czy_aktywna THEN
            RAISE EXCEPTION 'Usługa o nazwie "%" już istnieje w cenniku!', p_nazwa;
        ELSE
            
            UPDATE uslugi 
            SET czas_trwania = p_czas,
                cena = p_cena,
                czy_aktywna = TRUE
            WHERE id_uslugi = v_istniejace_id;
            
            v_procesowane_id := v_istniejace_id;
            
            
            DELETE FROM uslugi_specjalizacje WHERE id_uslugi = v_procesowane_id;
        END IF;
    ELSE
        
        INSERT INTO uslugi (nazwa, czas_trwania, cena, czy_aktywna) 
        VALUES (p_nazwa, p_czas, p_cena, TRUE)
        RETURNING id_uslugi INTO v_procesowane_id;
    END IF;

   
    IF p_specjalizacje IS NOT NULL AND array_length(p_specjalizacje, 1) > 0 THEN
        INSERT INTO uslugi_specjalizacje (id_uslugi, id_specjalizacji)
        SELECT v_procesowane_id, unnest(p_specjalizacje);
    END IF;

EXCEPTION
    WHEN numeric_value_out_of_range THEN
        RAISE EXCEPTION 'Podana cena jest zbyt wysoka.';
    WHEN string_data_right_truncation THEN
         RAISE EXCEPTION 'Nazwa usługi jest zbyt długa.';
    
END;
$$;


ALTER PROCEDURE public.dodaj_usluge(IN p_nazwa character varying, IN p_czas integer, IN p_cena numeric, IN p_specjalizacje integer[]) OWNER TO postgres;

--
-- TOC entry 264 (class 1255 OID 25157)
-- Name: dodaj_wizyte(timestamp without time zone, character varying, integer, integer, integer, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.dodaj_wizyte(IN p_data timestamp without time zone, IN p_status character varying, IN p_id_klienta integer, IN p_id_pracownika integer, IN p_id_uslugi integer, IN p_rola_uzytkownika_klikajacego character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_nowe_id_wizyty INT;
    v_czy_aktywny BOOLEAN;
    v_posiadane_specjalizacje INT;
    v_godzina TIME;
    v_dzien_tygodnia INT;
    v_rola_celu_wizyty VARCHAR; 
    v_czas_trwania_nowej INT;
    v_koniec_nowej TIMESTAMP;
BEGIN
    
    IF p_rola_uzytkownika_klikajacego NOT IN ('klient', 'pracownik', 'admin') THEN
        RAISE EXCEPTION 'Brak uprawnień do umawiania wizyt.';
    END IF;

    SELECT rola INTO v_rola_celu_wizyty FROM klienci WHERE id_klienta = p_id_klienta;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Wybrany klient (ID: %) nie istnieje w bazie!', p_id_klienta;
    END IF;

    IF LOWER(TRIM(v_rola_celu_wizyty)) != 'klient' THEN
        RAISE EXCEPTION '⛔ BLOKADA SYSTEMOWA: Nie można umówić wizyty dla konta z rolą "%". Wizyty są dozwolone TYLKO dla klientów!', v_rola_celu_wizyty;
    END IF;

    
    SELECT czas_trwania, czy_aktywna INTO v_czas_trwania_nowej, v_czy_aktywny 
    FROM uslugi 
    WHERE id_uslugi = p_id_uslugi;

    IF NOT FOUND THEN RAISE EXCEPTION 'Usługa nie istnieje.';
    ELSIF v_czy_aktywny = FALSE THEN RAISE EXCEPTION 'Usługa jest nieaktywna!'; END IF;

    
    IF v_czas_trwania_nowej IS NULL THEN v_czas_trwania_nowej := 60; END IF;

  
    v_koniec_nowej := p_data + (v_czas_trwania_nowej * interval '1 minute');

    
    IF p_data IS NULL OR p_data <= LOCALTIMESTAMP THEN
        RAISE EXCEPTION 'Data wizyty musi być w przyszłości!';
    END IF;

    IF trim(p_status) = '' THEN
        RAISE EXCEPTION 'Status wizyty jest wymagany!';
    END IF;

    v_godzina := CAST(p_data AS TIME);
    v_dzien_tygodnia := EXTRACT(DOW FROM p_data);

    IF v_dzien_tygodnia = 0 THEN RAISE EXCEPTION 'Salon jest nieczynny w niedziele!'; END IF;

    
    IF v_godzina < '09:00:00' OR CAST(v_koniec_nowej AS TIME) > '18:00:00' THEN 
        RAISE EXCEPTION 'Salon czynny 09:00-18:00. Wizyta (czas trwania: % min) musi zakończyć się przed 18:00!', v_czas_trwania_nowej; 
    END IF;

    SELECT czy_aktywny INTO v_czy_aktywny FROM klienci WHERE id_klienta = p_id_klienta;
    IF v_czy_aktywny = FALSE THEN RAISE EXCEPTION 'Nie można umówić usuniętego klienta!'; END IF;

    SELECT czy_aktywny INTO v_czy_aktywny FROM pracownicy WHERE id_pracownika = p_id_pracownika;
    IF NOT FOUND THEN RAISE EXCEPTION 'Pracownik nie istnieje.';
    ELSIF v_czy_aktywny = FALSE THEN RAISE EXCEPTION 'Pracownik jest nieaktywny!'; END IF;

    
    SELECT COUNT(*) INTO v_posiadane_specjalizacje 
    FROM pracownicy_specjalizacje ps 
    JOIN uslugi_specjalizacje us ON ps.id_specjalizacji = us.id_specjalizacji 
    WHERE ps.id_pracownika = p_id_pracownika AND us.id_uslugi = p_id_uslugi;

   
    IF v_posiadane_specjalizacje = 0 THEN 
        RAISE EXCEPTION 'Ten pracownik nie posiada wymaganej specjalizacji do tej usługi!'; 
    END IF;

    IF EXISTS (
        SELECT 1 
        FROM pracownicy_wizyty pw 
        JOIN wizyty w ON pw.id_wizyty = w.id_wizyty 
        JOIN wizyty_uslugi wu ON w.id_wizyty = wu.id_wizyty 
        JOIN uslugi u_istniejaca ON wu.id_uslugi = u_istniejaca.id_uslugi 
        WHERE pw.id_pracownika = p_id_pracownika 
          AND w.status != 'odwołana'
          AND (
            
            (w.data_wizyty < v_koniec_nowej) 
            AND 
            ((w.data_wizyty + (COALESCE(u_istniejaca.czas_trwania, 60) * interval '1 minute')) > p_data)
          )
    ) THEN
        RAISE EXCEPTION 'Ten pracownik ma już inną wizytę w tym przedziale czasowym!';
    END IF;

  
    INSERT INTO wizyty (data_wizyty, status) VALUES (p_data, p_status::status_enum) RETURNING id_wizyty INTO v_nowe_id_wizyty;
    INSERT INTO klienci_wizyty (id_wizyty, id_klienta) VALUES (v_nowe_id_wizyty, p_id_klienta);
    INSERT INTO pracownicy_wizyty (id_wizyty, id_pracownika) VALUES (v_nowe_id_wizyty, p_id_pracownika);
    INSERT INTO wizyty_uslugi (id_wizyty, id_uslugi) VALUES (v_nowe_id_wizyty, p_id_uslugi);

EXCEPTION
    WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'Nieprawidłowy status wizyty!';
END;
$$;


ALTER PROCEDURE public.dodaj_wizyte(IN p_data timestamp without time zone, IN p_status character varying, IN p_id_klienta integer, IN p_id_pracownika integer, IN p_id_uslugi integer, IN p_rola_uzytkownika_klikajacego character varying) OWNER TO postgres;

--
-- TOC entry 238 (class 1255 OID 25158)
-- Name: obsluz_usuniecie_opinii(integer, integer, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.obsluz_usuniecie_opinii(IN p_id_opinii integer, IN p_id_uzytkownika integer, IN p_rola text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_wlasciciel_opinii integer;
BEGIN
   
    SELECT id_klienta INTO v_wlasciciel_opinii
    FROM klienci_opinie
    WHERE id_opinii = p_id_opinii;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Opinia nie istnieje.';
    END IF;

   
    IF p_rola = 'admin' THEN
        DELETE FROM wizyty_opinie WHERE id_opinii = p_id_opinii;
        DELETE FROM klienci_opinie WHERE id_opinii = p_id_opinii;
        DELETE FROM opinie WHERE id_opinii = p_id_opinii;

   
    ELSIF p_rola = 'pracownik' THEN
        UPDATE opinie SET czy_aktywna = FALSE WHERE id_opinii = p_id_opinii;

   
    ELSIF p_rola = 'klient' THEN
        IF v_wlasciciel_opinii = p_id_uzytkownika THEN
            DELETE FROM wizyty_opinie WHERE id_opinii = p_id_opinii;
            DELETE FROM klienci_opinie WHERE id_opinii = p_id_opinii;
            DELETE FROM opinie WHERE id_opinii = p_id_opinii;
        ELSE
            RAISE EXCEPTION 'Nie masz uprawnień do usunięcia cudzej opinii!';
        END IF;
    
    ELSE
        RAISE EXCEPTION 'Nieznana rola użytkownika.';
    END IF;
END;
$$;


ALTER PROCEDURE public.obsluz_usuniecie_opinii(IN p_id_opinii integer, IN p_id_uzytkownika integer, IN p_rola text) OWNER TO postgres;

--
-- TOC entry 265 (class 1255 OID 25159)
-- Name: pobierz_dostepnych_pracownikow(integer, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pobierz_dostepnych_pracownikow(p_id_uslugi integer, p_data_wizyty timestamp without time zone) RETURNS TABLE(id_pracownika integer, imie text, nazwisko text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_czas_trwania_nowej INT;
    v_data_koniec TIMESTAMP;
BEGIN
   
    SELECT COALESCE(czas_trwania, 60) INTO v_czas_trwania_nowej 
    FROM uslugi 
    WHERE id_uslugi = p_id_uslugi;

    v_data_koniec := p_data_wizyty + (v_czas_trwania_nowej * interval '1 minute');

    RETURN QUERY
    SELECT 
        p.id_pracownika, 
        p.imie::text, 
        p.nazwisko::text
    FROM pracownicy p
    JOIN pracownicy_specjalizacje ps ON p.id_pracownika = ps.id_pracownika
    JOIN uslugi_specjalizacje us ON ps.id_specjalizacji = us.id_specjalizacji
    WHERE p.czy_aktywny = TRUE
      AND us.id_uslugi = p_id_uslugi
      
      AND p.id_pracownika NOT IN (
          SELECT pw.id_pracownika 
          FROM pracownicy_wizyty pw
          JOIN wizyty w ON pw.id_wizyty = w.id_wizyty
          JOIN wizyty_uslugi wu ON w.id_wizyty = wu.id_wizyty
          JOIN uslugi u_istniejaca ON wu.id_uslugi = u_istniejaca.id_uslugi
          WHERE w.status != 'odwołana'
          AND (
             (w.data_wizyty < v_data_koniec) 
             AND 
             ((w.data_wizyty + (COALESCE(u_istniejaca.czas_trwania, 60) * interval '1 minute')) > p_data_wizyty)
          )
      )
      
    GROUP BY p.id_pracownika, p.imie, p.nazwisko
    HAVING COUNT(*) > 0
    ORDER BY p.nazwisko;
END;
$$;


ALTER FUNCTION public.pobierz_dostepnych_pracownikow(p_id_uslugi integer, p_data_wizyty timestamp without time zone) OWNER TO postgres;

--
-- TOC entry 266 (class 1255 OID 25160)
-- Name: pobierz_klienta(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pobierz_klienta(p_id integer) RETURNS TABLE(id_klienta integer, imie character varying, nazwisko character varying, email character varying, haslo character varying, rola public.rola_enum, czy_aktywny boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        k.id_klienta, 
        k.imie, 
        k.nazwisko, 
        k.email, 
        k.haslo, 
        k.rola,
        k.czy_aktywny
    FROM klienci k 
    WHERE k.id_klienta = p_id;
END;
$$;


ALTER FUNCTION public.pobierz_klienta(p_id integer) OWNER TO postgres;

--
-- TOC entry 267 (class 1255 OID 25161)
-- Name: pobierz_opinie_dla_roli(integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pobierz_opinie_dla_roli(p_id_uzytkownika integer, p_rola text) RETURNS TABLE(id_opinii integer, id_wizyty integer, ocena integer, komentarz text, data_dodania timestamp without time zone, czy_aktywna boolean, klient_imie text, klient_nazwisko text, id_klienta integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_rola IN ('admin', 'pracownik') THEN
        RETURN QUERY 
        SELECT 
            o.id_opinii, 
            wo.id_wizyty,
            o.ocena, 
            o.komentarz, 
            o.created_at AS data_dodania,
            o.czy_aktywna,
            k.imie::text, 
            k.nazwisko::text, 
            k.id_klienta
        FROM opinie o
        JOIN wizyty_opinie wo ON o.id_opinii = wo.id_opinii
        JOIN klienci_opinie ko ON o.id_opinii = ko.id_opinii
        JOIN klienci k ON ko.id_klienta = k.id_klienta
        ORDER BY o.created_at DESC; 
    ELSE
        RETURN QUERY 
        SELECT 
            o.id_opinii, 
            wo.id_wizyty, 
            o.ocena, 
            o.komentarz, 
            o.created_at AS data_dodania, 
            o.czy_aktywna,
            k.imie::text, 
            k.nazwisko::text, 
            k.id_klienta
        FROM opinie o
        JOIN wizyty_opinie wo ON o.id_opinii = wo.id_opinii
        JOIN klienci_opinie ko ON o.id_opinii = ko.id_opinii
        JOIN klienci k ON ko.id_klienta = k.id_klienta
        WHERE o.czy_aktywna = TRUE 
           OR k.id_klienta = p_id_uzytkownika
        ORDER BY o.created_at DESC;
    END IF;
END;
$$;


ALTER FUNCTION public.pobierz_opinie_dla_roli(p_id_uzytkownika integer, p_rola text) OWNER TO postgres;

--
-- TOC entry 268 (class 1255 OID 25162)
-- Name: pobierz_pracownika(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pobierz_pracownika(p_id integer) RETURNS TABLE(id_pracownika integer, imie character varying, nazwisko character varying, pesel character varying, numer_telefonu character varying, zarobki_pln numeric, czy_aktywny boolean, specjalizacje_ids integer[])
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        p.id_pracownika, 
        p.imie, 
        p.nazwisko, 
        p.pesel, 
        p.numer_telefonu, 
        p.zarobki_PLN,
        p.czy_aktywny,
        COALESCE(
            array_agg(ps.id_specjalizacji) FILTER (WHERE ps.id_specjalizacji IS NOT NULL), 
            '{}'
        ) as specjalizacje_ids
    FROM pracownicy p
    LEFT JOIN pracownicy_specjalizacje ps ON p.id_pracownika = ps.id_pracownika
    WHERE p.id_pracownika = p_id
    GROUP BY p.id_pracownika;
END;
$$;


ALTER FUNCTION public.pobierz_pracownika(p_id integer) OWNER TO postgres;

--
-- TOC entry 269 (class 1255 OID 25163)
-- Name: pobierz_profil(integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pobierz_profil(p_id integer, p_rola text) RETURNS TABLE(imie text, nazwisko text, email text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT k.imie::text, k.nazwisko::text, k.email::text 
    FROM klienci k 
    WHERE k.id_klienta = p_id;
END;
$$;


ALTER FUNCTION public.pobierz_profil(p_id integer, p_rola text) OWNER TO postgres;

--
-- TOC entry 270 (class 1255 OID 25164)
-- Name: pobierz_specjalizacje(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pobierz_specjalizacje(p_id integer) RETURNS TABLE(id_specjalizacji integer, nazwa character varying, czy_aktywna boolean, uslugi_ids integer[])
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        s.id_specjalizacji, 
        s.nazwa, 
        s.czy_aktywna,
        COALESCE(
            array_agg(us.id_uslugi) FILTER (WHERE us.id_uslugi IS NOT NULL), 
            '{}'
        ) as uslugi_ids
    FROM specjalizacje s
    LEFT JOIN uslugi_specjalizacje us ON s.id_specjalizacji = us.id_specjalizacji
    WHERE s.id_specjalizacji = p_id
    GROUP BY s.id_specjalizacji;
END;
$$;


ALTER FUNCTION public.pobierz_specjalizacje(p_id integer) OWNER TO postgres;

--
-- TOC entry 271 (class 1255 OID 25165)
-- Name: pobierz_usluge(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pobierz_usluge(p_id integer) RETURNS TABLE(id_uslugi integer, nazwa character varying, czas_trwania integer, cena numeric, czy_aktywna boolean, specjalizacje_ids integer[])
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        u.id_uslugi, 
        u.nazwa, 
        u.czas_trwania, 
        u.cena,
        u.czy_aktywna,
        COALESCE(
            array_agg(us.id_specjalizacji) FILTER (WHERE us.id_specjalizacji IS NOT NULL), 
            '{}'
        ) as specjalizacje_ids
    FROM uslugi u
    LEFT JOIN uslugi_specjalizacje us ON u.id_uslugi = us.id_uslugi
    WHERE u.id_uslugi = p_id
    GROUP BY u.id_uslugi;
END;
$$;


ALTER FUNCTION public.pobierz_usluge(p_id integer) OWNER TO postgres;

--
-- TOC entry 272 (class 1255 OID 25166)
-- Name: pobierz_wizyte(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pobierz_wizyte(p_id_wizyty integer) RETURNS TABLE(id_wizyty integer, data_wizyty timestamp without time zone, status public.status_enum, id_klienta integer, id_pracownika integer, id_uslugi integer, klient_imie text, klient_nazwisko text, pracownik_imie text, pracownik_nazwisko text, usluga_nazwa text, usluga_cena numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        w.id_wizyty,
        w.data_wizyty,
        w.status,
        k.id_klienta,
        p.id_pracownika,
        u.id_uslugi,
        k.imie::text,
        k.nazwisko::text,
        p.imie::text,
        p.nazwisko::text,
        u.nazwa::text,
        u.cena
    FROM wizyty w
    LEFT JOIN klienci_wizyty kw ON w.id_wizyty = kw.id_wizyty
    LEFT JOIN klienci k ON kw.id_klienta = k.id_klienta
    LEFT JOIN pracownicy_wizyty pw ON w.id_wizyty = pw.id_wizyty
    LEFT JOIN pracownicy p ON pw.id_pracownika = p.id_pracownika
    LEFT JOIN wizyty_uslugi wu ON w.id_wizyty = wu.id_wizyty
    LEFT JOIN uslugi u ON wu.id_uslugi = u.id_uslugi
    WHERE w.id_wizyty = p_id_wizyty;
END;
$$;


ALTER FUNCTION public.pobierz_wizyte(p_id_wizyty integer) OWNER TO postgres;

--
-- TOC entry 273 (class 1255 OID 25167)
-- Name: pobierz_wizyty_dla_roli(integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pobierz_wizyty_dla_roli(p_id_uzytkownika integer, p_rola text) RETURNS TABLE(id_wizyty integer, data_wizyty timestamp without time zone, status public.status_enum, klient_imie text, klient_nazwisko text, pracownik_imie text, pracownik_nazwisko text, usluga_nazwa text, czy_oceniona boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_rola IN ('admin', 'pracownik') THEN
        RETURN QUERY 
        SELECT w.id_wizyty, w.data_wizyty, w.status,
               k.imie::text, k.nazwisko::text,
               p.imie::text, p.nazwisko::text,
               u.nazwa::text,
               EXISTS(SELECT 1 FROM wizyty_opinie wo WHERE wo.id_wizyty = w.id_wizyty) AS czy_oceniona
        FROM wizyty w
        LEFT JOIN klienci_wizyty kw ON w.id_wizyty = kw.id_wizyty
        LEFT JOIN klienci k ON kw.id_klienta = k.id_klienta
        LEFT JOIN pracownicy_wizyty pw ON w.id_wizyty = pw.id_wizyty
        LEFT JOIN pracownicy p ON pw.id_pracownika = p.id_pracownika
        LEFT JOIN wizyty_uslugi wu ON w.id_wizyty = wu.id_wizyty
        LEFT JOIN uslugi u ON wu.id_uslugi = u.id_uslugi
        ORDER BY w.data_wizyty DESC;

    ELSE
        RETURN QUERY 
        SELECT w.id_wizyty, w.data_wizyty, w.status,
               k.imie::text, k.nazwisko::text,
               p.imie::text, p.nazwisko::text,
               u.nazwa::text,
               EXISTS(SELECT 1 FROM wizyty_opinie wo WHERE wo.id_wizyty = w.id_wizyty) AS czy_oceniona
        FROM wizyty w
        JOIN klienci_wizyty kw ON w.id_wizyty = kw.id_wizyty
        JOIN klienci k ON kw.id_klienta = k.id_klienta
        LEFT JOIN pracownicy_wizyty pw ON w.id_wizyty = pw.id_wizyty
        LEFT JOIN pracownicy p ON pw.id_pracownika = p.id_pracownika
        LEFT JOIN wizyty_uslugi wu ON w.id_wizyty = wu.id_wizyty
        LEFT JOIN uslugi u ON wu.id_uslugi = u.id_uslugi
        WHERE kw.id_klienta = p_id_uzytkownika
        ORDER BY w.data_wizyty DESC;
    END IF;
END;
$$;


ALTER FUNCTION public.pobierz_wizyty_dla_roli(p_id_uzytkownika integer, p_rola text) OWNER TO postgres;

--
-- TOC entry 274 (class 1255 OID 25168)
-- Name: pobierz_wszystkich_klientow(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pobierz_wszystkich_klientow() RETURNS TABLE(id_klienta integer, imie character varying, nazwisko character varying, email character varying, haslo character varying, rola public.rola_enum, czy_aktywny boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        k.id_klienta, 
        k.imie, 
        k.nazwisko, 
        k.email, 
        k.haslo, 
        k.rola,
        k.czy_aktywny
    FROM klienci k 
    ORDER BY k.id_klienta ASC;
END;
$$;


ALTER FUNCTION public.pobierz_wszystkich_klientow() OWNER TO postgres;

--
-- TOC entry 275 (class 1255 OID 25169)
-- Name: pobierz_wszystkich_pracownikow(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pobierz_wszystkich_pracownikow() RETURNS TABLE(id_pracownika integer, imie character varying, nazwisko character varying, pesel character varying, numer_telefonu character varying, zarobki_pln numeric, czy_aktywny boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        p.id_pracownika, 
        p.imie, 
        p.nazwisko,
        p.pesel,
        p.numer_telefonu,
        p.zarobki_PLN,
        p.czy_aktywny 
    FROM pracownicy p 
    ORDER BY p.id_pracownika ASC;
END;
$$;


ALTER FUNCTION public.pobierz_wszystkich_pracownikow() OWNER TO postgres;

--
-- TOC entry 276 (class 1255 OID 25170)
-- Name: pobierz_wszystkie_opinie(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pobierz_wszystkie_opinie() RETURNS TABLE(id_opinii integer, ocena integer, komentarz text, data_dodania timestamp without time zone, czy_aktywna boolean, klient_imie character varying, klient_nazwisko character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        o.id_opinii, 
        o.ocena, 
        o.komentarz, 
        o.created_at,
        o.czy_aktywna,
        k.imie,
        k.nazwisko
    FROM opinie o
    
    JOIN klienci_opinie ko ON o.id_opinii = ko.id_opinii
    
    JOIN klienci k ON ko.id_klienta = k.id_klienta
    ORDER BY o.created_at DESC;
END;
$$;


ALTER FUNCTION public.pobierz_wszystkie_opinie() OWNER TO postgres;

--
-- TOC entry 277 (class 1255 OID 25171)
-- Name: pobierz_wszystkie_specjalizacje(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pobierz_wszystkie_specjalizacje() RETURNS TABLE(id_specjalizacji integer, nazwa character varying, czy_aktywna boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        s.id_specjalizacji, 
        s.nazwa, 
        s.czy_aktywna 
    FROM specjalizacje s 
    ORDER BY s.id_specjalizacji ASC;
END;
$$;


ALTER FUNCTION public.pobierz_wszystkie_specjalizacje() OWNER TO postgres;

--
-- TOC entry 278 (class 1255 OID 25172)
-- Name: pobierz_wszystkie_uslugi(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pobierz_wszystkie_uslugi() RETURNS TABLE(id_uslugi integer, nazwa character varying, czas_trwania integer, cena numeric, czy_aktywna boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        u.id_uslugi, 
        u.nazwa, 
        u.czas_trwania, 
        u.cena,
        u.czy_aktywna
    FROM uslugi u 
    ORDER BY u.id_uslugi ASC;
END;
$$;


ALTER FUNCTION public.pobierz_wszystkie_uslugi() OWNER TO postgres;

--
-- TOC entry 279 (class 1255 OID 25173)
-- Name: pobierz_wszystkie_wizyty(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pobierz_wszystkie_wizyty() RETURNS TABLE(id_wizyty integer, data_wizyty timestamp without time zone, status public.status_enum, klient_imie character varying, klient_nazwisko character varying, pracownik_imie character varying, pracownik_nazwisko character varying, usluga_nazwa character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        w.id_wizyty, 
        w.data_wizyty, 
        w.status,
        k.imie, 
        k.nazwisko,
        p.imie, 
        p.nazwisko,
        u.nazwa
    FROM wizyty w  
    JOIN klienci_wizyty kw ON w.id_wizyty = kw.id_wizyty
    JOIN klienci k ON kw.id_klienta = k.id_klienta
    
    JOIN pracownicy_wizyty pw ON w.id_wizyty = pw.id_wizyty
    JOIN pracownicy p ON pw.id_pracownika = p.id_pracownika
    
    JOIN wizyty_uslugi wu ON w.id_wizyty = wu.id_wizyty
    JOIN uslugi u ON wu.id_uslugi = u.id_uslugi
    
    ORDER BY w.data_wizyty DESC;
END;
$$;


ALTER FUNCTION public.pobierz_wszystkie_wizyty() OWNER TO postgres;

--
-- TOC entry 280 (class 1255 OID 25174)
-- Name: przywroc_opinie(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.przywroc_opinie(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_rows_affected int;
BEGIN
    UPDATE opinie 
    SET czy_aktywna = TRUE 
    WHERE id_opinii = p_id;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected = 0 THEN
        RAISE EXCEPTION 'Nie znaleziono opinii o ID %.', p_id;
    END IF;
END;
$$;


ALTER PROCEDURE public.przywroc_opinie(IN p_id integer) OWNER TO postgres;

--
-- TOC entry 281 (class 1255 OID 25175)
-- Name: rap_10_utracone_zarobki(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rap_10_utracone_zarobki() RETURNS TABLE(wynik_imie character varying, wynik_nazwisko character varying, wynik_strata numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    r_wiersz RECORD;
BEGIN
    FOR r_wiersz IN 
        SELECT 
            p.imie, 
            p.nazwisko, 
            COALESCE(SUM(u.cena), 0) as suma_strat
        FROM pracownicy p
        JOIN pracownicy_wizyty pw ON p.id_pracownika = pw.id_pracownika
        JOIN wizyty w ON w.id_wizyty = pw.id_wizyty
        JOIN wizyty_uslugi wu ON wu.id_wizyty = w.id_wizyty
        JOIN uslugi u ON u.id_uslugi = wu.id_uslugi
        WHERE TRIM(LOWER(w.status::text)) = 'odwołana'
        GROUP BY p.id_pracownika, p.imie, p.nazwisko
        HAVING COALESCE(SUM(u.cena), 0) > 0  
        ORDER BY suma_strat DESC 
    LOOP
        wynik_imie := r_wiersz.imie;
        wynik_nazwisko := r_wiersz.nazwisko;
        wynik_strata := r_wiersz.suma_strat;
        RETURN NEXT;
    END LOOP;

    RETURN;
END;
$$;


ALTER FUNCTION public.rap_10_utracone_zarobki() OWNER TO postgres;

--
-- TOC entry 282 (class 1255 OID 25176)
-- Name: rap_1_top_pracownik(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rap_1_top_pracownik() RETURNS TABLE(wynik_imie character varying, wynik_nazwisko character varying, wynik_przychod numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    r_prac RECORD;
    v_przychod_prac NUMERIC;
    v_best_przychod NUMERIC := -100;
    v_best_imie VARCHAR := 'Brak';
    v_best_nazwisko VARCHAR := 'Danych';
BEGIN
    
    FOR r_prac IN SELECT p.id_pracownika, p.imie, p.nazwisko FROM pracownicy p LOOP
        
        SELECT COALESCE(SUM(u.cena), 0) INTO v_przychod_prac
        FROM pracownicy_wizyty pw
        JOIN wizyty w ON w.id_wizyty = pw.id_wizyty
        JOIN wizyty_uslugi wu ON wu.id_wizyty = w.id_wizyty
        JOIN uslugi u ON u.id_uslugi = wu.id_uslugi
        WHERE pw.id_pracownika = r_prac.id_pracownika 
        
        AND TRIM(LOWER(w.status::text)) = 'zakończona';

        IF v_przychod_prac > v_best_przychod THEN
            v_best_przychod := v_przychod_prac;
            v_best_imie := r_prac.imie;
            v_best_nazwisko := r_prac.nazwisko;
        END IF;
    END LOOP;

   
    wynik_imie := v_best_imie;
    wynik_nazwisko := v_best_nazwisko;
    wynik_przychod := v_best_przychod;
    
    RETURN NEXT; 
END;
$$;


ALTER FUNCTION public.rap_1_top_pracownik() OWNER TO postgres;

--
-- TOC entry 283 (class 1255 OID 25177)
-- Name: rap_2_top_klienci(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rap_2_top_klienci() RETURNS TABLE(imie character varying, nazwisko character varying, liczba_wizyt bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    r_klient RECORD;
    i INT := 0;
BEGIN
    FOR r_klient IN 
        SELECT k.imie, k.nazwisko, COUNT(w.id_wizyty) as cnt
        FROM klienci k
        JOIN klienci_wizyty kw ON k.id_klienta = kw.id_klienta
        JOIN wizyty w ON w.id_wizyty = kw.id_wizyty
        WHERE w.status = 'zakończona'
        GROUP BY k.id_klienta, k.imie, k.nazwisko
        ORDER BY cnt DESC
    LOOP
        
        i := i + 1;
        IF i > 3 THEN EXIT; END IF;

        imie := r_klient.imie;
        nazwisko := r_klient.nazwisko;
        liczba_wizyt := r_klient.cnt;
        RETURN NEXT;
    END LOOP;
END;
$$;


ALTER FUNCTION public.rap_2_top_klienci() OWNER TO postgres;

--
-- TOC entry 284 (class 1255 OID 25178)
-- Name: rap_3_srednia_wartosc(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rap_3_srednia_wartosc() RETURNS TABLE(srednia numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    r_wizyta RECORD;
    v_suma_laczna NUMERIC := 0;
    v_liczba_wizyt INT := 0;
BEGIN
    FOR r_wizyta IN SELECT id_wizyty FROM wizyty WHERE status = 'zakończona' LOOP
        
        v_suma_laczna := v_suma_laczna + (
            SELECT COALESCE(SUM(u.cena), 0) 
            FROM wizyty_uslugi wu 
            JOIN uslugi u ON u.id_uslugi = wu.id_uslugi 
            WHERE wu.id_wizyty = r_wizyta.id_wizyty
        );
        v_liczba_wizyt := v_liczba_wizyt + 1;
    END LOOP;

    IF v_liczba_wizyt > 0 THEN
        srednia := ROUND(v_suma_laczna / v_liczba_wizyt, 2);
    ELSE
        srednia := 0;
    END IF;
    RETURN NEXT;
END;
$$;


ALTER FUNCTION public.rap_3_srednia_wartosc() OWNER TO postgres;

--
-- TOC entry 285 (class 1255 OID 25179)
-- Name: rap_4_czasochlonna(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rap_4_czasochlonna() RETURNS TABLE(nazwa_uslugi character varying, laczny_czas integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    r_usluga RECORD;
    v_czas_biezacy INT;
    v_max_czas INT := -1;
BEGIN
   
    FOR r_usluga IN SELECT id_uslugi, nazwa, czas_trwania FROM uslugi LOOP
       
        SELECT count(*) * COALESCE(r_usluga.czas_trwania, 60) INTO v_czas_biezacy
        FROM wizyty_uslugi wu
        JOIN wizyty w ON w.id_wizyty = wu.id_wizyty
        WHERE wu.id_uslugi = r_usluga.id_uslugi 
          AND TRIM(LOWER(w.status::text)) = 'zakończona';

 
        IF v_czas_biezacy > v_max_czas THEN
            v_max_czas := v_czas_biezacy;
        END IF;
    END LOOP;

    
    IF v_max_czas > 0 THEN
        FOR r_usluga IN SELECT id_uslugi, nazwa, czas_trwania FROM uslugi LOOP
            
            
            SELECT count(*) * COALESCE(r_usluga.czas_trwania, 60) INTO v_czas_biezacy
            FROM wizyty_uslugi wu
            JOIN wizyty w ON w.id_wizyty = wu.id_wizyty
            WHERE wu.id_uslugi = r_usluga.id_uslugi 
              AND TRIM(LOWER(w.status::text)) = 'zakończona';

            
            IF v_czas_biezacy = v_max_czas THEN
                nazwa_uslugi := r_usluga.nazwa;
                laczny_czas := v_max_czas;
                RETURN NEXT;
            END IF;
        END LOOP;
    END IF;
    
    RETURN;
END;
$$;


ALTER FUNCTION public.rap_4_czasochlonna() OWNER TO postgres;

--
-- TOC entry 286 (class 1255 OID 25180)
-- Name: rap_5_oceny(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rap_5_oceny() RETURNS TABLE(pracownik character varying, srednia numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    r_prac RECORD;
BEGIN
    FOR r_prac IN SELECT id_pracownika, imie, nazwisko FROM pracownicy LOOP
        pracownik := r_prac.imie || ' ' || r_prac.nazwisko;
        
        SELECT ROUND(AVG(o.ocena), 2) INTO srednia
        FROM pracownicy_wizyty pw
        JOIN wizyty_opinie wo ON wo.id_wizyty = pw.id_wizyty
        JOIN opinie o ON o.id_opinii = wo.id_opinii
        WHERE pw.id_pracownika = r_prac.id_pracownika;

        IF srednia IS NOT NULL THEN
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$$;


ALTER FUNCTION public.rap_5_oceny() OWNER TO postgres;

--
-- TOC entry 287 (class 1255 OID 25181)
-- Name: rap_6_procent_odwolanych(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rap_6_procent_odwolanych() RETURNS TABLE(odwolane integer, wszystkie integer, procent numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    r_wizyta RECORD;
BEGIN
    odwolane := 0;
    wszystkie := 0;
    
    FOR r_wizyta IN SELECT status FROM wizyty LOOP
        wszystkie := wszystkie + 1;
        IF r_wizyta.status = 'odwołana' THEN
            odwolane := odwolane + 1;
        END IF;
    END LOOP;

    IF wszystkie > 0 THEN
        procent := ROUND((odwolane::numeric / wszystkie::numeric) * 100, 2);
    ELSE
        procent := 0;
    END IF;
    RETURN NEXT;
END;
$$;


ALTER FUNCTION public.rap_6_procent_odwolanych() OWNER TO postgres;

--
-- TOC entry 288 (class 1255 OID 25182)
-- Name: rap_7_top_usluga(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rap_7_top_usluga() RETURNS TABLE(nazwa_uslugi character varying, liczba integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    r_usluga RECORD;
    v_count INT;
    v_max INT := -1;
    v_name VARCHAR;
BEGIN

    FOR r_usluga IN SELECT id_uslugi, nazwa FROM uslugi LOOP
        
        SELECT COUNT(*) INTO v_count
        FROM wizyty_uslugi wu
        JOIN wizyty w ON w.id_wizyty = wu.id_wizyty
        WHERE wu.id_uslugi = r_usluga.id_uslugi 

          AND TRIM(LOWER(w.status::text)) = 'zakończona';

        IF v_count > v_max THEN
            v_max := v_count;
            v_name := r_usluga.nazwa;
        END IF;
    END LOOP;

    nazwa_uslugi := v_name;
    liczba := v_max;
    RETURN NEXT;
END;
$$;


ALTER FUNCTION public.rap_7_top_usluga() OWNER TO postgres;

--
-- TOC entry 289 (class 1255 OID 25183)
-- Name: rap_8_bez_wizyt(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rap_8_bez_wizyt() RETURNS TABLE(wynik_klient character varying, wynik_email character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    r_klient RECORD;
    v_liczba INT;
BEGIN
    
    FOR r_klient IN 
        SELECT id_klienta, imie, nazwisko, email 
        FROM klienci 
        WHERE rola = 'klient'
    LOOP
        
       
        SELECT COUNT(*) INTO v_liczba
        FROM klienci_wizyty
        WHERE id_klienta = r_klient.id_klienta;

        
        IF v_liczba = 0 THEN
            wynik_klient := r_klient.imie || ' ' || r_klient.nazwisko;
            wynik_email := r_klient.email;
            RETURN NEXT;
        END IF;
    END LOOP;
    
    RETURN;
END;
$$;


ALTER FUNCTION public.rap_8_bez_wizyt() OWNER TO postgres;

--
-- TOC entry 290 (class 1255 OID 25184)
-- Name: rap_9_top_dzien(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rap_9_top_dzien() RETURNS TABLE(dzien character varying, przychod numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    r_dane RECORD;
    v_max NUMERIC := -1;
    v_best_day_eng VARCHAR;
    v_best_day_pl VARCHAR;
    v_data_start DATE;
    v_data_koniec DATE;
BEGIN
    SELECT MIN(data_wizyty)::DATE, MAX(data_wizyty)::DATE 
    INTO v_data_start, v_data_koniec 
    FROM wizyty;

    FOR r_dane IN 
        WITH kalendarz AS (
            SELECT generate_series(v_data_start, v_data_koniec, '1 day'::interval)::DATE as data_dnia
        )
        SELECT 
            TRIM(TO_CHAR(k.data_dnia, 'Day')) as d,
            ROUND(
                COALESCE(SUM(u.cena), 0) / COUNT(k.data_dnia), 
            2) as s
        FROM kalendarz k
        LEFT JOIN wizyty w ON w.data_wizyty::DATE = k.data_dnia 
                           AND TRIM(LOWER(w.status::text)) = 'zakończona'
        LEFT JOIN wizyty_uslugi wu ON w.id_wizyty = wu.id_wizyty
        LEFT JOIN uslugi u ON u.id_uslugi = wu.id_uslugi
        GROUP BY d
    LOOP
        IF r_dane.s > v_max THEN
            v_max := r_dane.s;
            v_best_day_eng := r_dane.d;
        END IF;
    END LOOP;

    CASE v_best_day_eng
        WHEN 'Monday' THEN v_best_day_pl := 'Poniedziałek';
        WHEN 'Tuesday' THEN v_best_day_pl := 'Wtorek';
        WHEN 'Wednesday' THEN v_best_day_pl := 'Środa';
        WHEN 'Thursday' THEN v_best_day_pl := 'Czwartek';
        WHEN 'Friday' THEN v_best_day_pl := 'Piątek';
        WHEN 'Saturday' THEN v_best_day_pl := 'Sobota';
        WHEN 'Sunday' THEN v_best_day_pl := 'Niedziela';
        ELSE v_best_day_pl := 'Brak danych';
    END CASE;

    IF v_max >= 0 THEN
        dzien := v_best_day_pl;
        przychod := v_max;
        RETURN NEXT;
    END IF;

    RETURN;
END;
$$;


ALTER FUNCTION public.rap_9_top_dzien() OWNER TO postgres;

--
-- TOC entry 291 (class 1255 OID 25185)
-- Name: usun_klienta(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.usun_klienta(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_czy_ma_powiazania boolean;
BEGIN
    
    SELECT EXISTS (
        SELECT 1 FROM klienci_wizyty WHERE id_klienta = p_id
        UNION ALL
        SELECT 1 FROM klienci_opinie WHERE id_klienta = p_id
    ) INTO v_czy_ma_powiazania;

    
    IF v_czy_ma_powiazania THEN
        
        UPDATE klienci 
        SET czy_aktywny = FALSE 
        WHERE id_klienta = p_id;
        RAISE NOTICE 'Klient ID % posiada historię - wykonano archiwizację.', p_id;
    ELSE
        
        DELETE FROM klienci WHERE id_klienta = p_id;
        
        IF NOT FOUND THEN
             RAISE EXCEPTION 'Nie znaleziono klienta o ID %.', p_id;
        END IF;
    END IF;
END;
$$;


ALTER PROCEDURE public.usun_klienta(IN p_id integer) OWNER TO postgres;

--
-- TOC entry 292 (class 1255 OID 25186)
-- Name: usun_opinie(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.usun_opinie(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_rows_affected int;
BEGIN
    UPDATE opinie 
    SET czy_aktywna = FALSE 
    WHERE id_opinii = p_id;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected = 0 THEN
        RAISE EXCEPTION 'Nie znaleziono opinii o ID %.', p_id;
    END IF;
    
    
END;
$$;


ALTER PROCEDURE public.usun_opinie(IN p_id integer) OWNER TO postgres;

--
-- TOC entry 250 (class 1255 OID 25187)
-- Name: usun_pracownika(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.usun_pracownika(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_czy_ma_powiazania boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pracownicy_wizyty WHERE id_pracownika = p_id
        UNION ALL
        SELECT 1 FROM pracownicy_specjalizacje WHERE id_pracownika = p_id
    ) INTO v_czy_ma_powiazania;

    IF v_czy_ma_powiazania THEN
        UPDATE pracownicy 
        SET czy_aktywny = FALSE 
        WHERE id_pracownika = p_id;
        RAISE NOTICE 'Pracownik ID % posiada historię - wykonano archiwizację.', p_id;
    ELSE
        DELETE FROM pracownicy WHERE id_pracownika = p_id;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Nie znaleziono pracownika o ID %.', p_id;
        END IF;
    END IF;
END;
$$;


ALTER PROCEDURE public.usun_pracownika(IN p_id integer) OWNER TO postgres;

--
-- TOC entry 293 (class 1255 OID 25188)
-- Name: usun_specjalizacje(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.usun_specjalizacje(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_czy_ma_powiazania boolean;
BEGIN
    
    SELECT EXISTS (
        SELECT 1 FROM pracownicy_specjalizacje WHERE id_specjalizacji = p_id
        UNION ALL
        SELECT 1 FROM uslugi_specjalizacje WHERE id_specjalizacji = p_id
    ) INTO v_czy_ma_powiazania;

    
    IF v_czy_ma_powiazania THEN
        
        UPDATE specjalizacje 
        SET czy_aktywna = FALSE 
        WHERE id_specjalizacji = p_id;
        RAISE NOTICE 'Specjalizacja ID % jest używana - wykonano archiwizację.', p_id;
    ELSE
        
        DELETE FROM specjalizacje WHERE id_specjalizacji = p_id;
        
        IF NOT FOUND THEN
             RAISE EXCEPTION 'Nie znaleziono specjalizacji o ID %.', p_id;
        END IF;
    END IF;
END;
$$;


ALTER PROCEDURE public.usun_specjalizacje(IN p_id integer) OWNER TO postgres;

--
-- TOC entry 296 (class 1255 OID 25189)
-- Name: usun_usluge(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.usun_usluge(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_czy_ma_powiazania boolean;
BEGIN
    
    SELECT EXISTS (
        SELECT 1 FROM wizyty_uslugi WHERE id_uslugi = p_id
        UNION ALL
        SELECT 1 FROM uslugi_specjalizacje WHERE id_uslugi = p_id
    ) INTO v_czy_ma_powiazania;

    
    IF v_czy_ma_powiazania THEN
        
        UPDATE uslugi 
        SET czy_aktywna = FALSE 
        WHERE id_uslugi = p_id;
        RAISE NOTICE 'Usługa ID % jest używana - wykonano archiwizację.', p_id;
    ELSE
        
        DELETE FROM uslugi WHERE id_uslugi = p_id;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Nie znaleziono usługi o ID %.', p_id;
        END IF;
    END IF;
END;
$$;


ALTER PROCEDURE public.usun_usluge(IN p_id integer) OWNER TO postgres;

--
-- TOC entry 294 (class 1255 OID 25190)
-- Name: usun_wizyte(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.usun_wizyte(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_rows_affected int;
BEGIN
    UPDATE wizyty 
    SET status = 'odwołana' 
    WHERE id_wizyty = p_id;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected = 0 THEN
        RAISE EXCEPTION 'Nie znaleziono wizyty o ID %.', p_id;
    END IF;
END;
$$;


ALTER PROCEDURE public.usun_wizyte(IN p_id integer) OWNER TO postgres;

--
-- TOC entry 295 (class 1255 OID 25191)
-- Name: zaloguj_uzytkownika(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.zaloguj_uzytkownika(p_email text, p_haslo text) RETURNS TABLE(id_klienta integer, imie text, nazwisko text, rola public.rola_enum)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        k.id_klienta, 
        k.imie::text,
        k.nazwisko::text,
        k.rola
    FROM klienci k
    WHERE k.email = p_email 
      AND k.haslo = p_haslo 
      AND k.czy_aktywny = TRUE;
END;
$$;


ALTER FUNCTION public.zaloguj_uzytkownika(p_email text, p_haslo text) OWNER TO postgres;

--
-- TOC entry 243 (class 1255 OID 25192)
-- Name: zarejestruj_sie(character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.zarejestruj_sie(IN p_imie character varying, IN p_nazwisko character varying, IN p_email character varying, IN p_haslo character varying)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_istniejacy_id INT;
BEGIN
    
    IF trim(p_imie) = '' OR trim(p_nazwisko) = '' OR trim(p_email) = '' OR trim(p_haslo) = '' THEN
        RAISE EXCEPTION 'Wszystkie pola są wymagane!';
    END IF;

    IF p_email !~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$' THEN
        RAISE EXCEPTION 'Nieprawidłowy format adresu email!';
    END IF;

    
    SELECT id_klienta INTO v_istniejacy_id FROM klienci WHERE email = p_email;
    
    IF FOUND THEN
        RAISE EXCEPTION 'Użytkownik o takim adresie email już istnieje!';
    END IF;

   
    INSERT INTO klienci (imie, nazwisko, email, haslo, rola, czy_aktywny)
    VALUES (p_imie, p_nazwisko, p_email, p_haslo, 'klient', TRUE);

EXCEPTION
    WHEN string_data_right_truncation THEN
         RAISE EXCEPTION 'Wprowadzone dane są zbyt długie.';
END;
$_$;


ALTER PROCEDURE public.zarejestruj_sie(IN p_imie character varying, IN p_nazwisko character varying, IN p_email character varying, IN p_haslo character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 219 (class 1259 OID 25193)
-- Name: klienci; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.klienci (
    id_klienta integer NOT NULL,
    imie character varying NOT NULL,
    nazwisko character varying NOT NULL,
    email character varying NOT NULL,
    haslo character varying NOT NULL,
    rola public.rola_enum DEFAULT 'klient'::public.rola_enum NOT NULL,
    czy_aktywny boolean DEFAULT true
);


ALTER TABLE public.klienci OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 25206)
-- Name: klienci_id_klienta_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.klienci_id_klienta_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.klienci_id_klienta_seq OWNER TO postgres;

--
-- TOC entry 5191 (class 0 OID 0)
-- Dependencies: 220
-- Name: klienci_id_klienta_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.klienci_id_klienta_seq OWNED BY public.klienci.id_klienta;


--
-- TOC entry 221 (class 1259 OID 25207)
-- Name: klienci_opinie; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.klienci_opinie (
    id_opinii integer NOT NULL,
    id_klienta integer NOT NULL
);


ALTER TABLE public.klienci_opinie OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 25212)
-- Name: klienci_wizyty; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.klienci_wizyty (
    id_klienta integer NOT NULL,
    id_wizyty integer NOT NULL
);


ALTER TABLE public.klienci_wizyty OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 25217)
-- Name: opinie; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.opinie (
    id_opinii integer NOT NULL,
    ocena integer NOT NULL,
    komentarz text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    czy_aktywna boolean DEFAULT true,
    CONSTRAINT opinie_ocena_check CHECK (((ocena >= 1) AND (ocena <= 5)))
);


ALTER TABLE public.opinie OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 25228)
-- Name: opinie_id_opinii_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.opinie_id_opinii_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.opinie_id_opinii_seq OWNER TO postgres;

--
-- TOC entry 5192 (class 0 OID 0)
-- Dependencies: 224
-- Name: opinie_id_opinii_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.opinie_id_opinii_seq OWNED BY public.opinie.id_opinii;


--
-- TOC entry 225 (class 1259 OID 25229)
-- Name: pracownicy; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pracownicy (
    id_pracownika integer NOT NULL,
    imie character varying NOT NULL,
    nazwisko character varying NOT NULL,
    numer_telefonu character varying(20),
    zarobki_pln numeric(10,2),
    czy_aktywny boolean DEFAULT true,
    pesel character varying(11)
);


ALTER TABLE public.pracownicy OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 25238)
-- Name: pracownicy_id_pracownika_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pracownicy_id_pracownika_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pracownicy_id_pracownika_seq OWNER TO postgres;

--
-- TOC entry 5193 (class 0 OID 0)
-- Dependencies: 226
-- Name: pracownicy_id_pracownika_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pracownicy_id_pracownika_seq OWNED BY public.pracownicy.id_pracownika;


--
-- TOC entry 227 (class 1259 OID 25239)
-- Name: pracownicy_specjalizacje; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pracownicy_specjalizacje (
    id_pracownika integer NOT NULL,
    id_specjalizacji integer NOT NULL
);


ALTER TABLE public.pracownicy_specjalizacje OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 25244)
-- Name: pracownicy_wizyty; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pracownicy_wizyty (
    id_pracownika integer NOT NULL,
    id_wizyty integer NOT NULL
);


ALTER TABLE public.pracownicy_wizyty OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 25249)
-- Name: specjalizacje; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.specjalizacje (
    id_specjalizacji integer NOT NULL,
    nazwa character varying NOT NULL,
    czy_aktywna boolean DEFAULT true
);


ALTER TABLE public.specjalizacje OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 25257)
-- Name: specjalizacje_id_specjalizacji_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.specjalizacje_id_specjalizacji_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.specjalizacje_id_specjalizacji_seq OWNER TO postgres;

--
-- TOC entry 5194 (class 0 OID 0)
-- Dependencies: 230
-- Name: specjalizacje_id_specjalizacji_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.specjalizacje_id_specjalizacji_seq OWNED BY public.specjalizacje.id_specjalizacji;


--
-- TOC entry 231 (class 1259 OID 25258)
-- Name: uslugi; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.uslugi (
    id_uslugi integer NOT NULL,
    nazwa character varying NOT NULL,
    czas_trwania integer NOT NULL,
    cena numeric(10,2) NOT NULL,
    czy_aktywna boolean DEFAULT true
);


ALTER TABLE public.uslugi OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 25268)
-- Name: uslugi_id_uslugi_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.uslugi_id_uslugi_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.uslugi_id_uslugi_seq OWNER TO postgres;

--
-- TOC entry 5195 (class 0 OID 0)
-- Dependencies: 232
-- Name: uslugi_id_uslugi_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.uslugi_id_uslugi_seq OWNED BY public.uslugi.id_uslugi;


--
-- TOC entry 233 (class 1259 OID 25269)
-- Name: uslugi_specjalizacje; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.uslugi_specjalizacje (
    id_uslugi integer NOT NULL,
    id_specjalizacji integer NOT NULL
);


ALTER TABLE public.uslugi_specjalizacje OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 25274)
-- Name: wizyty; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.wizyty (
    id_wizyty integer NOT NULL,
    data_wizyty timestamp without time zone NOT NULL,
    status public.status_enum NOT NULL
);


ALTER TABLE public.wizyty OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 25280)
-- Name: wizyty_id_wizyty_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.wizyty_id_wizyty_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.wizyty_id_wizyty_seq OWNER TO postgres;

--
-- TOC entry 5196 (class 0 OID 0)
-- Dependencies: 235
-- Name: wizyty_id_wizyty_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.wizyty_id_wizyty_seq OWNED BY public.wizyty.id_wizyty;


--
-- TOC entry 236 (class 1259 OID 25281)
-- Name: wizyty_opinie; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.wizyty_opinie (
    id_wizyty integer NOT NULL,
    id_opinii integer NOT NULL
);


ALTER TABLE public.wizyty_opinie OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 25286)
-- Name: wizyty_uslugi; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.wizyty_uslugi (
    id_wizyty integer NOT NULL,
    id_uslugi integer NOT NULL
);


ALTER TABLE public.wizyty_uslugi OWNER TO postgres;

--
-- TOC entry 4963 (class 2604 OID 25291)
-- Name: klienci id_klienta; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.klienci ALTER COLUMN id_klienta SET DEFAULT nextval('public.klienci_id_klienta_seq'::regclass);


--
-- TOC entry 4966 (class 2604 OID 25292)
-- Name: opinie id_opinii; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.opinie ALTER COLUMN id_opinii SET DEFAULT nextval('public.opinie_id_opinii_seq'::regclass);


--
-- TOC entry 4969 (class 2604 OID 25293)
-- Name: pracownicy id_pracownika; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pracownicy ALTER COLUMN id_pracownika SET DEFAULT nextval('public.pracownicy_id_pracownika_seq'::regclass);


--
-- TOC entry 4971 (class 2604 OID 25294)
-- Name: specjalizacje id_specjalizacji; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.specjalizacje ALTER COLUMN id_specjalizacji SET DEFAULT nextval('public.specjalizacje_id_specjalizacji_seq'::regclass);


--
-- TOC entry 4973 (class 2604 OID 25295)
-- Name: uslugi id_uslugi; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.uslugi ALTER COLUMN id_uslugi SET DEFAULT nextval('public.uslugi_id_uslugi_seq'::regclass);


--
-- TOC entry 4975 (class 2604 OID 25296)
-- Name: wizyty id_wizyty; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wizyty ALTER COLUMN id_wizyty SET DEFAULT nextval('public.wizyty_id_wizyty_seq'::regclass);


--
-- TOC entry 5167 (class 0 OID 25193)
-- Dependencies: 219
-- Data for Name: klienci; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.klienci (id_klienta, imie, nazwisko, email, haslo, rola, czy_aktywny) FROM stdin;
1	admin	admin	admin@salon.pl	admin	admin	t
2	Adam	Kowalski	adam.kowalski189@outlook.com	test123	klient	t
3	Julia	Nowak	julia.nowak304@wp.pl	test123	klient	t
4	Mateusz	Wiśniewski	mateusz.wisniewski696@yahoo.com	test123	klient	t
5	Zuzanna	Wójcik	zuzanna.wojcik103@o2.pl	test123	klient	t
6	Kacper	Kowalczyk	kacper.kowalczyk734@interia.pl	test123	klient	t
7	Maja	Kamińska	maja.kaminska951@o2.pl	test123	klient	t
8	Jakub	Lewandowski	jakub.lewandowski508@interia.pl	test123	klient	t
9	Alicja	Zielińska	alicja.zielinska394@outlook.com	test123	klient	t
10	Szymon	Szymański	szymon.szymanski368@interia.pl	test123	klient	t
11	Hanna	Woźniak	hanna.wozniak410@o2.pl	test123	klient	t
12	Filip	Dąbrowski	filip.dabrowski922@interia.pl	test123	klient	t
13	Oliwia	Kozłowska	oliwia.kozlowska846@yahoo.com	test123	klient	t
14	Antoni	Jankowski	antoni.jankowski678@interia.pl	test123	klient	t
15	Amelia	Mazur	amelia.mazur126@yahoo.com	test123	klient	t
16	Wojciech	Kwiatkowski	wojciech.kwiatkowski394@o2.pl	test123	klient	t
17	Lena	Wojciechowska	lena.wojciechowska941@onet.pl	test123	klient	t
18	Michał	Krawczyk	michal.krawczyk520@gmail.com	test123	klient	t
19	Emilia	Kaczmarek	emilia.kaczmarek393@outlook.com	test123	klient	t
20	Aleksander	Piotrowski	aleksander.piotrowski547@gmail.com	test123	klient	t
21	Pola	Grabowska	pola.grabowska475@yahoo.com	test123	klient	t
22	Bartosz	Zając	bartosz.zajac23@o2.pl	test123	klient	t
23	Natalia	Pawłowska	natalia.pawlowska845@interia.pl	test123	klient	t
24	Piotr	Michalski	piotr.michalski530@yahoo.com	test123	klient	t
25	Wiktoria	Król	wiktoria.krol245@onet.pl	test123	klient	t
26	Tomasz	Wieczorek	tomasz.wieczorek350@gmail.com	test123	klient	t
27	Aleksandra	Jabłońska	aleksandra.jablonska909@outlook.com	test123	klient	t
28	Konrad	Wróbel	konrad.wrobel426@onet.pl	test123	klient	t
29	Iga	Nowicka	iga.nowicka789@onet.pl	test123	klient	t
30	Paweł	Majewski	pawel.majewski123@outlook.com	test123	klient	t
31	Nina	Olszewska	nina.olszewska942@gmail.com	test123	klient	t
32	Marcel	Stępień	marcel.stepien360@interia.pl	test123	klient	t
33	Gabriela	Jaworska	gabriela.jaworska273@gmail.com	test123	klient	t
34	Damian	Malinowski	damian.malinowski328@interia.pl	test123	klient	t
35	Sara	Adamczyk	sara.adamczyk377@outlook.com	test123	klient	t
36	Igor	Dudek	igor.dudek407@outlook.com	test123	klient	t
37	Klaudia	Zalewska	klaudia.zalewska854@gmail.com	test123	klient	t
38	Łukasz	Pietrzak	lukasz.pietrzak784@interia.pl	test123	klient	t
39	Anna	Rutkowska	anna.rutkowska183@onet.pl	test123	klient	t
40	Hubert	Górski	hubert.gorski95@outlook.com	test123	klient	t
41	Kinga	Sikora	kinga.sikora485@o2.pl	test123	klient	t
42	Karol	Baran	karol.baran733@interia.pl	test123	klient	t
43	Monika	Szulc	monika.szulc300@gmail.com	test123	klient	t
44	Norbert	Sadowski	norbert.sadowski848@yahoo.com	test123	klient	t
45	Ewa	Błaszczyk	ewa.blaszczyk120@interia.pl	test123	klient	t
46	Rafał	Chmielewski	rafal.chmielewski646@interia.pl	test123	klient	t
47	Magdalena	Lis	magdalena.lis458@onet.pl	test123	klient	t
48	Grzegorz	Kubiak	grzegorz.kubiak314@gmail.com	test123	klient	t
49	Joanna	Brzezińska	joanna.brzezinska493@outlook.com	test123	klient	t
50	Patryk	Makowski	patryk.makowski593@onet.pl	test123	klient	t
51	Weronika	Czarnecka	weronika.czarnecka980@onet.pl	test123	klient	t
52	Adam	Nowicki	adam.nowicki@salon.pl	test123	pracownik	t
53	Ewa	Szymczak	ewa.szymczak@salon.pl	test123	pracownik	t
54	Krzysztof	Malinowski	krzysztof.malinowski@salon.pl	test123	pracownik	t
55	Monika	Baran	monika.baran@salon.pl	test123	pracownik	t
56	Jacek	Krupa	jacek.krupa@salon.pl	test123	pracownik	t
57	Paulina	Czarnecka	paulina.czarnecka@salon.pl	test123	pracownik	t
58	Wojciech	Jakubik	wojciech.jakubik@salon.pl	test123	pracownik	t
59	Zuzanna	Grabowska	zuzanna.grabowska@salon.pl	test123	pracownik	t
60	Bartosz	Wilk	bartosz.wilk@salon.pl	test123	pracownik	t
61	Helena	Król	helena.krol@salon.pl	test123	pracownik	t
62	Patryk	Mickiewicz	patryk.mickiewicz28@gmail.com	patmic	klient	t
\.


--
-- TOC entry 5169 (class 0 OID 25207)
-- Dependencies: 221
-- Data for Name: klienci_opinie; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.klienci_opinie (id_opinii, id_klienta) FROM stdin;
1	2
2	3
3	12
4	39
5	22
6	38
7	9
8	47
9	6
10	46
\.


--
-- TOC entry 5170 (class 0 OID 25212)
-- Dependencies: 222
-- Data for Name: klienci_wizyty; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.klienci_wizyty (id_klienta, id_wizyty) FROM stdin;
25	17
28	18
27	19
17	21
41	22
42	23
26	24
30	25
7	27
36	28
43	30
2	1
3	2
12	3
39	4
22	5
38	6
6	7
47	8
9	9
46	10
18	11
23	12
8	13
33	14
45	15
20	20
31	26
50	29
4	31
3	32
9	33
5	34
2	35
62	36
48	16
\.


--
-- TOC entry 5171 (class 0 OID 25217)
-- Dependencies: 223
-- Data for Name: opinie; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.opinie (id_opinii, ocena, komentarz, created_at, czy_aktywna) FROM stdin;
1	5	Bardzo profesjonalne strzyżenie, dokładnie tak jak chciałem. Miła atmosfera i szybka obsługa. Na pewno wrócę.	2026-01-15 18:23:51.892638	t
2	4	Strzyżenie damskie wykonane starannie, fryzjerka doradziła odpowiednią fryzurę. Jestem zadowolona z efektu.	2026-01-15 18:24:33.986191	t
3	5	Combo strzyżenie + zarost na najwyższym poziomie. Wszystko dokładnie i estetycznie wykonane.	2026-01-15 18:25:08.873339	t
4	5	Koloryzacja wyszła idealnie, kolor dokładnie taki jak chciałam. Pełen profesjonalizm.	2026-01-15 18:26:24.80572	t
5	4	Zarost + kontur zrobione bardzo precyzyjnie. Obsługa miła, salon czysty i zadbany.	2026-01-15 18:27:48.493828	t
6	5	Masaż klasyczny bardzo relaksujący, idealny po ciężkim dniu. Polecam każdemu.	2026-01-15 18:30:19.562461	t
7	3	Stylizacja była okej, choć trwała trochę dłużej niż się spodziewałam. Efekt końcowy poprawny.	2026-01-15 18:33:23.023377	t
8	4	Strzyżenie damskie wykonane bardzo dokładnie, obsługa sympatyczna i pomocna.	2026-01-15 18:34:01.94261	t
9	3	Strzyżenie w porządku, ale bez efektu wow. Fryzura poprawna, jednak liczyłem na więcej doradztwa.	2026-01-15 18:35:58.312702	t
10	5	Stylizacja brody wykonana perfekcyjnie, wszystko dopracowane w najmniejszym szczególe.	2026-01-15 18:38:20.019845	t
\.


--
-- TOC entry 5173 (class 0 OID 25229)
-- Dependencies: 225
-- Data for Name: pracownicy; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pracownicy (id_pracownika, imie, nazwisko, numer_telefonu, zarobki_pln, czy_aktywny, pesel) FROM stdin;
1	Adam	Nowicki	873324764	5000.00	t	85031201234
3	Krzysztof	Malinowski	115453453	4300.00	t	76052033445
5	Jacek	Krupa	276654844	6800.00	t	88122411223
9	Bartosz	Wilk	509435833	7500.00	t	90101022334
7	Wojciech	Jakubik	347876345	5000.00	t	01251244556
2	Ewa	Szymczak	876324634	3500.00	t	92110567891
4	Monika	Baran	654765335	4000.00	t	99011556667
6	Paulina	Czarnecka	528980436	6500.00	t	95073099887
8	Zuzanna	Grabowska	864652904	3500.00	t	83041877665
10	Helena	Król	513455761	4300.00	t	79112200998
\.


--
-- TOC entry 5175 (class 0 OID 25239)
-- Dependencies: 227
-- Data for Name: pracownicy_specjalizacje; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pracownicy_specjalizacje (id_pracownika, id_specjalizacji) FROM stdin;
1	1
3	1
5	6
9	2
7	2
2	3
4	3
6	3
6	5
8	4
10	7
\.


--
-- TOC entry 5176 (class 0 OID 25244)
-- Dependencies: 228
-- Data for Name: pracownicy_wizyty; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pracownicy_wizyty (id_pracownika, id_wizyty) FROM stdin;
2	17
7	18
4	19
8	21
6	22
5	23
3	24
1	25
2	27
7	28
10	30
9	1
2	2
1	3
6	4
5	5
10	6
7	7
4	8
8	9
1	10
9	11
10	12
3	13
8	14
6	15
9	20
6	26
3	29
1	31
2	32
10	33
9	34
10	35
7	36
1	16
\.


--
-- TOC entry 5177 (class 0 OID 25249)
-- Dependencies: 229
-- Data for Name: specjalizacje; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.specjalizacje (id_specjalizacji, nazwa, czy_aktywna) FROM stdin;
1	Barber	t
2	Fryzjer męski	t
3	Fryzjer damski	t
4	Stylista fryzur	t
5	Koloryzacja włosów	t
6	Stylista brody	t
7	Masażysta	t
\.


--
-- TOC entry 5179 (class 0 OID 25258)
-- Dependencies: 231
-- Data for Name: uslugi; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.uslugi (id_uslugi, nazwa, czas_trwania, cena, czy_aktywna) FROM stdin;
1	Strzyżenie męskie	30	50.00	t
2	Strzyżenie damskie	45	80.00	t
3	Koloryzacja	120	200.00	t
4	Masaż klasyczny	60	120.00	t
5	Stylizacja brody	60	90.00	t
6	Combo (strzyżenie + zarost)	60	110.00	t
7	Stylizacja	50	50.00	t
8	Zarost + kontur	40	60.00	t
9	Zabieg twarzy	50	140.00	t
\.


--
-- TOC entry 5181 (class 0 OID 25269)
-- Dependencies: 233
-- Data for Name: uslugi_specjalizacje; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.uslugi_specjalizacje (id_uslugi, id_specjalizacji) FROM stdin;
1	1
1	2
2	3
3	3
3	2
3	5
4	7
5	1
5	6
6	1
7	3
7	2
7	4
8	1
8	6
9	7
\.


--
-- TOC entry 5182 (class 0 OID 25274)
-- Dependencies: 234
-- Data for Name: wizyty; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.wizyty (id_wizyty, data_wizyty, status) FROM stdin;
17	2026-01-19 15:00:00	zaplanowana
18	2026-01-19 16:15:00	zaplanowana
19	2026-01-20 09:15:00	zaplanowana
21	2026-01-20 11:45:00	zaplanowana
22	2026-01-20 13:00:00	zaplanowana
23	2026-01-20 14:30:00	zaplanowana
24	2026-01-20 16:00:00	zaplanowana
25	2026-01-21 09:00:00	zaplanowana
27	2026-01-21 11:45:00	zaplanowana
28	2026-01-21 13:00:00	zaplanowana
30	2026-01-21 16:15:00	zaplanowana
1	2026-01-16 09:15:00	zakończona
2	2026-01-16 10:30:00	zakończona
3	2026-01-16 12:00:00	zakończona
4	2026-01-16 13:30:00	zakończona
5	2026-01-16 15:00:00	zakończona
6	2026-01-16 16:15:00	zakończona
7	2026-01-17 09:00:00	zakończona
8	2026-01-17 10:15:00	zakończona
9	2026-01-17 11:30:00	zakończona
10	2026-01-17 13:00:00	zakończona
11	2026-01-17 14:30:00	zakończona
12	2026-01-17 16:00:00	zakończona
13	2026-01-19 09:30:00	zakończona
14	2026-01-19 10:45:00	zakończona
15	2026-01-19 12:15:00	zakończona
20	2026-01-20 10:30:00	odwołana
26	2026-01-21 10:30:00	odwołana
29	2026-01-21 14:30:00	odwołana
31	2026-01-29 16:54:00	zaplanowana
32	2026-02-03 15:55:00	zaplanowana
33	2026-01-29 15:55:00	zaplanowana
34	2026-02-03 11:00:00	zaplanowana
35	2026-01-19 10:35:00	zakończona
36	2026-01-23 16:00:00	zaplanowana
16	2026-01-19 13:30:00	w toku
\.


--
-- TOC entry 5184 (class 0 OID 25281)
-- Dependencies: 236
-- Data for Name: wizyty_opinie; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.wizyty_opinie (id_wizyty, id_opinii) FROM stdin;
1	1
2	2
3	3
4	4
5	5
6	6
9	7
8	8
7	9
10	10
\.


--
-- TOC entry 5185 (class 0 OID 25286)
-- Dependencies: 237
-- Data for Name: wizyty_uslugi; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.wizyty_uslugi (id_wizyty, id_uslugi) FROM stdin;
17	2
18	1
19	2
21	7
22	3
23	8
24	6
25	6
27	2
28	1
30	4
1	1
2	2
3	6
4	3
5	8
6	4
7	1
8	2
9	7
10	5
11	1
12	9
13	1
14	7
15	3
20	1
26	3
29	5
31	1
32	2
33	4
34	3
35	4
36	7
16	8
\.


--
-- TOC entry 5197 (class 0 OID 0)
-- Dependencies: 220
-- Name: klienci_id_klienta_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.klienci_id_klienta_seq', 62, true);


--
-- TOC entry 5198 (class 0 OID 0)
-- Dependencies: 224
-- Name: opinie_id_opinii_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.opinie_id_opinii_seq', 10, true);


--
-- TOC entry 5199 (class 0 OID 0)
-- Dependencies: 226
-- Name: pracownicy_id_pracownika_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.pracownicy_id_pracownika_seq', 1, false);


--
-- TOC entry 5200 (class 0 OID 0)
-- Dependencies: 230
-- Name: specjalizacje_id_specjalizacji_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.specjalizacje_id_specjalizacji_seq', 1, false);


--
-- TOC entry 5201 (class 0 OID 0)
-- Dependencies: 232
-- Name: uslugi_id_uslugi_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.uslugi_id_uslugi_seq', 1, false);


--
-- TOC entry 5202 (class 0 OID 0)
-- Dependencies: 235
-- Name: wizyty_id_wizyty_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.wizyty_id_wizyty_seq', 36, true);


--
-- TOC entry 4978 (class 2606 OID 25298)
-- Name: klienci klienci_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.klienci
    ADD CONSTRAINT klienci_email_key UNIQUE (email);


--
-- TOC entry 4982 (class 2606 OID 25300)
-- Name: klienci_opinie klienci_opinie_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.klienci_opinie
    ADD CONSTRAINT klienci_opinie_pkey PRIMARY KEY (id_opinii, id_klienta);


--
-- TOC entry 4980 (class 2606 OID 25302)
-- Name: klienci klienci_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.klienci
    ADD CONSTRAINT klienci_pkey PRIMARY KEY (id_klienta);


--
-- TOC entry 4984 (class 2606 OID 25304)
-- Name: klienci_wizyty klienci_wizyty_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.klienci_wizyty
    ADD CONSTRAINT klienci_wizyty_pkey PRIMARY KEY (id_klienta, id_wizyty);


--
-- TOC entry 4986 (class 2606 OID 25306)
-- Name: opinie opinie_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.opinie
    ADD CONSTRAINT opinie_pkey PRIMARY KEY (id_opinii);


--
-- TOC entry 4988 (class 2606 OID 25308)
-- Name: pracownicy pracownicy_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pracownicy
    ADD CONSTRAINT pracownicy_pkey PRIMARY KEY (id_pracownika);


--
-- TOC entry 4990 (class 2606 OID 25310)
-- Name: pracownicy_specjalizacje pracownicy_specjalizacje_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pracownicy_specjalizacje
    ADD CONSTRAINT pracownicy_specjalizacje_pkey PRIMARY KEY (id_pracownika, id_specjalizacji);


--
-- TOC entry 4992 (class 2606 OID 25312)
-- Name: pracownicy_wizyty pracownicy_wizyty_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pracownicy_wizyty
    ADD CONSTRAINT pracownicy_wizyty_pkey PRIMARY KEY (id_pracownika, id_wizyty);


--
-- TOC entry 4994 (class 2606 OID 25314)
-- Name: specjalizacje specjalizacje_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.specjalizacje
    ADD CONSTRAINT specjalizacje_pkey PRIMARY KEY (id_specjalizacji);


--
-- TOC entry 4996 (class 2606 OID 25316)
-- Name: uslugi uslugi_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.uslugi
    ADD CONSTRAINT uslugi_pkey PRIMARY KEY (id_uslugi);


--
-- TOC entry 4998 (class 2606 OID 25318)
-- Name: uslugi_specjalizacje uslugi_specjalizacje_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.uslugi_specjalizacje
    ADD CONSTRAINT uslugi_specjalizacje_pkey PRIMARY KEY (id_uslugi, id_specjalizacji);


--
-- TOC entry 5002 (class 2606 OID 25320)
-- Name: wizyty_opinie wizyty_opinie_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wizyty_opinie
    ADD CONSTRAINT wizyty_opinie_pkey PRIMARY KEY (id_wizyty, id_opinii);


--
-- TOC entry 5000 (class 2606 OID 25322)
-- Name: wizyty wizyty_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wizyty
    ADD CONSTRAINT wizyty_pkey PRIMARY KEY (id_wizyty);


--
-- TOC entry 5004 (class 2606 OID 25324)
-- Name: wizyty_uslugi wizyty_uslugi_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wizyty_uslugi
    ADD CONSTRAINT wizyty_uslugi_pkey PRIMARY KEY (id_wizyty, id_uslugi);


--
-- TOC entry 5019 (class 2620 OID 25325)
-- Name: wizyty trigger_blokada_zakonczonych; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_blokada_zakonczonych BEFORE UPDATE ON public.wizyty FOR EACH ROW EXECUTE FUNCTION public.blokada_zmiany_zakonczonych();


--
-- TOC entry 5005 (class 2606 OID 25326)
-- Name: klienci_opinie klienci_opinie_id_klienta_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.klienci_opinie
    ADD CONSTRAINT klienci_opinie_id_klienta_fkey FOREIGN KEY (id_klienta) REFERENCES public.klienci(id_klienta) ON DELETE CASCADE;


--
-- TOC entry 5006 (class 2606 OID 25331)
-- Name: klienci_opinie klienci_opinie_id_opinii_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.klienci_opinie
    ADD CONSTRAINT klienci_opinie_id_opinii_fkey FOREIGN KEY (id_opinii) REFERENCES public.opinie(id_opinii) ON DELETE CASCADE;


--
-- TOC entry 5007 (class 2606 OID 25336)
-- Name: klienci_wizyty klienci_wizyty_id_klienta_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.klienci_wizyty
    ADD CONSTRAINT klienci_wizyty_id_klienta_fkey FOREIGN KEY (id_klienta) REFERENCES public.klienci(id_klienta) ON DELETE RESTRICT;


--
-- TOC entry 5008 (class 2606 OID 25341)
-- Name: klienci_wizyty klienci_wizyty_id_wizyty_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.klienci_wizyty
    ADD CONSTRAINT klienci_wizyty_id_wizyty_fkey FOREIGN KEY (id_wizyty) REFERENCES public.wizyty(id_wizyty) ON DELETE CASCADE;


--
-- TOC entry 5009 (class 2606 OID 25346)
-- Name: pracownicy_specjalizacje pracownicy_specjalizacje_id_pracownika_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pracownicy_specjalizacje
    ADD CONSTRAINT pracownicy_specjalizacje_id_pracownika_fkey FOREIGN KEY (id_pracownika) REFERENCES public.pracownicy(id_pracownika) ON DELETE RESTRICT;


--
-- TOC entry 5010 (class 2606 OID 25351)
-- Name: pracownicy_specjalizacje pracownicy_specjalizacje_id_specjalizacji_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pracownicy_specjalizacje
    ADD CONSTRAINT pracownicy_specjalizacje_id_specjalizacji_fkey FOREIGN KEY (id_specjalizacji) REFERENCES public.specjalizacje(id_specjalizacji) ON DELETE RESTRICT;


--
-- TOC entry 5011 (class 2606 OID 25356)
-- Name: pracownicy_wizyty pracownicy_wizyty_id_pracownika_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pracownicy_wizyty
    ADD CONSTRAINT pracownicy_wizyty_id_pracownika_fkey FOREIGN KEY (id_pracownika) REFERENCES public.pracownicy(id_pracownika) ON DELETE RESTRICT;


--
-- TOC entry 5012 (class 2606 OID 25361)
-- Name: pracownicy_wizyty pracownicy_wizyty_id_wizyty_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pracownicy_wizyty
    ADD CONSTRAINT pracownicy_wizyty_id_wizyty_fkey FOREIGN KEY (id_wizyty) REFERENCES public.wizyty(id_wizyty) ON DELETE CASCADE;


--
-- TOC entry 5013 (class 2606 OID 25366)
-- Name: uslugi_specjalizacje uslugi_specjalizacje_id_specjalizacji_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.uslugi_specjalizacje
    ADD CONSTRAINT uslugi_specjalizacje_id_specjalizacji_fkey FOREIGN KEY (id_specjalizacji) REFERENCES public.specjalizacje(id_specjalizacji) ON DELETE RESTRICT;


--
-- TOC entry 5014 (class 2606 OID 25371)
-- Name: uslugi_specjalizacje uslugi_specjalizacje_id_uslugi_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.uslugi_specjalizacje
    ADD CONSTRAINT uslugi_specjalizacje_id_uslugi_fkey FOREIGN KEY (id_uslugi) REFERENCES public.uslugi(id_uslugi) ON DELETE RESTRICT;


--
-- TOC entry 5015 (class 2606 OID 25376)
-- Name: wizyty_opinie wizyty_opinie_id_opinii_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wizyty_opinie
    ADD CONSTRAINT wizyty_opinie_id_opinii_fkey FOREIGN KEY (id_opinii) REFERENCES public.opinie(id_opinii) ON DELETE CASCADE;


--
-- TOC entry 5016 (class 2606 OID 25381)
-- Name: wizyty_opinie wizyty_opinie_id_wizyty_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wizyty_opinie
    ADD CONSTRAINT wizyty_opinie_id_wizyty_fkey FOREIGN KEY (id_wizyty) REFERENCES public.wizyty(id_wizyty) ON DELETE CASCADE;


--
-- TOC entry 5017 (class 2606 OID 25386)
-- Name: wizyty_uslugi wizyty_uslugi_id_uslugi_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wizyty_uslugi
    ADD CONSTRAINT wizyty_uslugi_id_uslugi_fkey FOREIGN KEY (id_uslugi) REFERENCES public.uslugi(id_uslugi) ON DELETE RESTRICT;


--
-- TOC entry 5018 (class 2606 OID 25391)
-- Name: wizyty_uslugi wizyty_uslugi_id_wizyty_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wizyty_uslugi
    ADD CONSTRAINT wizyty_uslugi_id_wizyty_fkey FOREIGN KEY (id_wizyty) REFERENCES public.wizyty(id_wizyty) ON DELETE CASCADE;


-- Completed on 2026-01-18 16:08:54

--
-- PostgreSQL database dump complete
--

\unrestrict eEmXGXhov308j7UPBoqTxM283ieXAnlSmaeh9I17rND0Mh9XpLAr2n0dMSgqg2K

