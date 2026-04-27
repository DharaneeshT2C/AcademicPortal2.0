import { LightningElement, wire } from "lwc";
import getStudentSchedule from "@salesforce/apex/KenCourseEnrollmentController.getStudentSchedule";

export default class StudentHomeSchedule extends LightningElement {
  /* ================= STATE ================= */

  currentDate = new Date(); // month shown in calendar
  selectedDateKey = null; // YYYY-MM-DD
  scheduleMap = {}; // { dateKey: [schedule...] }

  /* ================= APEX ================= */

  @wire(getStudentSchedule)
  wiredSchedule({ data, error }) {
    if (data) {
      this.prepareSchedule(data);
    } else if (error) {
      // eslint-disable-next-line no-console
      console.error("Schedule error", error);
    }
  }

  /* ================= DATA PREP ================= */

  prepareSchedule(data) {
    this.scheduleMap = {};

    data.forEach((item) => {
      if (!this.scheduleMap[item.dateKey]) {
        this.scheduleMap[item.dateKey] = [];
      }

      this.scheduleMap[item.dateKey].push({
        ...item,
      });
    });

    // Default select first available date
    const keys = Object.keys(this.scheduleMap);
    if (keys.length) {
      this.selectedDateKey = keys[0];

      const [year, month] = keys[0].split("-");
      this.currentDate = new Date(Number(year), Number(month) - 1, 1);
    }
  }

  /* ================= SCHEDULE ================= */

  get daySchedules() {
    return this.scheduleMap[this.selectedDateKey] || [];
  }

  get hasDaySchedules() {
    return this.daySchedules.length > 0;
  }

  /* ================= CALENDAR ================= */

  get monthYearLabel() {
    return this.currentDate.toLocaleString("default", {
      month: "long",
      year: "numeric",
    });
  }

  prevMonth() {
    this.currentDate = new Date(this.currentDate.getFullYear(), this.currentDate.getMonth() - 1, 1);
  }

  nextMonth() {
    this.currentDate = new Date(this.currentDate.getFullYear(), this.currentDate.getMonth() + 1, 1);
  }

  get calendarDays() {
    const days = [];
    const year = this.currentDate.getFullYear();
    const month = this.currentDate.getMonth();

    const firstDay = new Date(year, month, 1).getDay();
    const totalDays = new Date(year, month + 1, 0).getDate();

    // Empty placeholders
    for (let i = 0; i < firstDay; i++) {
      days.push({
        label: "",
        date: null,
        className: "empty",
      });
    }

    // Actual days
    for (let d = 1; d <= totalDays; d++) {
      const key = `${year}-${String(month + 1).padStart(2, "0")}-${String(d).padStart(2, "0")}`;

      let cls = "day";
      if (key === this.selectedDateKey) {
        cls += " selected";
      }

      days.push({
        label: d,
        date: key,
        className: cls,
      });
    }

    return days;
  }

  selectDate(event) {
    const key = event.target.dataset.date;
    if (key) {
      this.selectedDateKey = key;
    }
  }
}