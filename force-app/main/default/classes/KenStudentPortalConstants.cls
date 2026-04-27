/**
 * ************************************************************************************************
 * @className  KenStudentPortalConstants
 *
 * @description
 *  Centralised constants shared across Student Portal Apex controllers and services.
 *
 *  Responsibilities:
 *  - Stage / career-path literal values driven from the LWC dev toolbar.
 *  - Schedule and feed enumerations consumed by the Home dashboard.
 *  - Brand identifiers used for themable responses.
 *  - Shared RecordType / sObject name strings.
 *
 * @author      Student Portal Backend
 * @createdOn   2026
 * ************************************************************************************************
 */
public with sharing class KenStudentPortalConstants {

    // ─── Stages (Home dashboard variants) ───────────────────────────────────────
    public static final String STAGE_STARTING = 'starting';
    public static final String STAGE_MIDDLE   = 'middle';
    public static final String STAGE_ENDING   = 'ending';

    // ─── Career paths (only meaningful in STAGE_ENDING) ─────────────────────────
    public static final String PATH_PLACEMENTS       = 'placements';
    public static final String PATH_HIGHER_STUDIES   = 'higher-studies';
    public static final String PATH_ENTREPRENEURSHIP = 'entrepreneurship';
    public static final String PATH_EXPLORING        = 'exploring';

    // ─── Brands ─────────────────────────────────────────────────────────────────
    public static final String BRAND_KEN = 'ken';
    public static final String BRAND_SMU = 'smu';

    // ─── KPI accent classes (mirror LWC dashboard.css tokens) ───────────────────
    public static final String ACCENT_INDIGO  = 'accent-indigo';
    public static final String ACCENT_VIOLET  = 'accent-violet';
    public static final String ACCENT_SKY     = 'accent-sky';
    public static final String ACCENT_EMERALD = 'accent-emerald';
    public static final String ACCENT_AMBER   = 'accent-amber';
    public static final String ACCENT_RED     = 'accent-red';
    public static final String ACCENT_GREEN   = 'accent-green';
    public static final String ACCENT_SLATE   = 'accent-slate';

    // ─── Feed tag classes ───────────────────────────────────────────────────────
    public static final String TAG_EVENT = 'tag-event';
    public static final String TAG_ACAD  = 'tag-acad';
    public static final String TAG_EXAM  = 'tag-exam';
    public static final String TAG_CLUB  = 'tag-club';
    public static final String TAG_ALERT = 'tag-alert';
    public static final String TAG_REG   = 'tag-reg';
    public static final String TAG_OFFER = 'tag-offer';
    public static final String TAG_CERT  = 'tag-cert';

    // ─── sObject / Platform names ───────────────────────────────────────────────
    public static final String SOBJECT_CONTACT = 'Contact';
    public static final String SOBJECT_USER    = 'User';
    public static final String SOBJECT_EVENT   = 'Event';

    // ─── Generic status labels ──────────────────────────────────────────────────
    public static final String STATUS_ACTIVE    = 'Active';
    public static final String STATUS_PENDING   = 'Pending';
    public static final String STATUS_COMPLETED = 'Completed';
    public static final String STATUS_DUE       = 'Due';
    public static final String STATUS_PAID      = 'Paid';

    // ─── Cache partition name for any Platform Cache usage ──────────────────────
    public static final String CACHE_PARTITION = 'local.StudentPortal';
}