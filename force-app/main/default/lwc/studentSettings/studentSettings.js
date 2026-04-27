import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCurrentUserProfile from '@salesforce/apex/SideNavigationController.getCurrentUserProfile';

const DEFAULT_FORM_DATA = {
    firstName: 'Joshua',
    lastName: 'B',
    dateOfBirth: '21-06-1999',
    gender: 'Male',
    email: 'nupu*****@gmail.com',
    phone: '+91 81694 *****',
    bloodGroup: 'O+ve',
    allergies: 'None',
    permanentHouse: '29',
    permanentStreet: '25 Live Oak Ave',
    permanentSuburb: 'Bay City',
    permanentCity: 'Texas',
    permanentPincode: '560041',
    currentHouse: '29',
    currentStreet: '25 Live Oak Ave',
    currentSuburb: 'Bay City',
    currentCity: 'Texas',
    currentPincode: '560041',
    guardianName: 'John David',
    guardianRelationship: 'Father',
    guardianPhone: '9791237956',
    guardianEmail: 'johndavid06@gmail.com',
    aadharNumber: '1234 5678 0987'
};

const DEFAULT_FACULTY_DATA = {
    profileName: 'Mallika K',
    profileId: 'ID9824',
    department: 'Dept. of Engineering',
    role: 'Faculty',
    specialisation: 'Electronics & Engineering',
    status: 'Active',
    idCardName: 'Mallika',
    gender: 'Female',
    dateOfBirth: '21-07-1991',
    nationality: 'Indian',
    countryOfResidence: 'India',
    birthPlace: 'Bangalore',
    phoneNumber: '6379416588',
    emailId: 'mallika@gmail.com',
    hidePhoneNumber: false,
    hideEmailId: false,
    password: '**********',
    bloodGroup: 'O+ve',
    allergies: 'None',
    others: 'None',
    permanentHouse: '00/00',
    permanentStreet: 'Kamaraj 2nd street',
    permanentSuburb: 'Kamaraj nagar',
    permanentCountry: 'India',
    permanentPincode: '007667',
    currentHouse: '00/00',
    currentStreet: 'Kamaraj 2nd street',
    currentSuburb: 'Kamaraj nagar',
    currentCountry: 'India',
    currentPincode: '007667',
    aadharNumber: '1234 5678 9876'
};

export default class StudentSettings extends LightningElement {
    formData = { ...DEFAULT_FORM_DATA };
    facultyFormData = { ...DEFAULT_FACULTY_DATA };

    userRole = '';
    profilePhotoUrl = '';

    activeModal = '';
    editPhoneValue = '';
    editEmailValue = '';
    otpDigits = ['', '', '', ''];
    currentPasswordInput = '';
    newPasswordInput = '';
    showCurrentPassword = false;
    showNewPassword = false;
    successTitle = '';
    successMessage = '';

    connectedCallback() {
        this.loadCurrentUserProfile();
    }

    async loadCurrentUserProfile() {
        try {
            const profile = await getCurrentUserProfile();
            this.userRole = profile?.roleType || '';
            this.profilePhotoUrl = profile?.photoUrl || '';
        } catch {
            this.userRole = '';
            this.profilePhotoUrl = '';
        }
    }

    get isFacultyRole() {
        return String(this.userRole || '').trim().toLowerCase() === 'faculty';
    }

    get isPhoneEditModalOpen() {
        return this.activeModal === 'phone';
    }

    get isOtpModalOpen() {
        return this.activeModal === 'otp';
    }

    get isEmailEditModalOpen() {
        return this.activeModal === 'email';
    }

    get isPasswordModalOpen() {
        return this.activeModal === 'password';
    }

    get isSuccessModalOpen() {
        return this.activeModal === 'success';
    }

    get isDiscardConfirmModalOpen() {
        return this.activeModal === 'discardConfirm';
    }

    get otpBoxes() {
        return this.otpDigits.map((digit, index) => ({
            id: `otp-${index}`,
            index,
            value: digit || ''
        }));
    }

    get currentPasswordType() {
        return this.showCurrentPassword ? 'text' : 'password';
    }

    get newPasswordType() {
        return this.showNewPassword ? 'text' : 'password';
    }

    get currentPasswordIcon() {
        return this.showCurrentPassword ? 'utility:hide' : 'utility:preview';
    }

    get newPasswordIcon() {
        return this.showNewPassword ? 'utility:hide' : 'utility:preview';
    }

    get profileInitials() {
        const firstInitial = (this.formData.firstName || '').charAt(0);
        const lastInitial = (this.formData.lastName || '').charAt(0);
        return `${firstInitial}${lastInitial}`.toUpperCase() || 'S';
    }

    get facultyProfileInitials() {
        const name = String(this.facultyFormData.profileName || '').trim();
        if (!name) {
            return 'F';
        }
        const parts = name.split(/\s+/).filter(Boolean);
        const first = (parts[0] || '').charAt(0);
        const second = (parts[1] || '').charAt(0);
        return `${first}${second}`.toUpperCase();
    }

    get genderOptions() {
        return this.toOptions(['Male', 'Female', 'Other'], this.formData.gender);
    }

    get bloodGroupOptions() {
        return this.toOptions(['O+ve', 'A+ve', 'B+ve', 'AB+ve'], this.formData.bloodGroup);
    }

    get allergyOptions() {
        return this.toOptions(['None', 'Dust', 'Pollen', 'Food'], this.formData.allergies);
    }

    get permanentCityOptions() {
        return this.toOptions(['Texas', 'California', 'Florida'], this.formData.permanentCity);
    }

    get currentCityOptions() {
        return this.toOptions(['Texas', 'California', 'Florida'], this.formData.currentCity);
    }

    get guardianRelationOptions() {
        return this.toOptions(['Father', 'Mother', 'Guardian'], this.formData.guardianRelationship);
    }

    handleInputChange(event) {
        const field = event.target.name || event.target.dataset.field;
        const value = event.detail?.value ?? event.target.value;

        if (this.isFacultyRole) {
            this.facultyFormData = {
                ...this.facultyFormData,
                [field]: value
            };
            return;
        }

        this.formData = {
            ...this.formData,
            [field]: value
        };
    }

    handleFacultyToggleChange(event) {
        const field = event.target.dataset.field;
        this.facultyFormData = {
            ...this.facultyFormData,
            [field]: event.target.checked
        };
    }

    handleBackdropClose() {
        this.closeModal();
    }

    stopModalClose(event) {
        event.stopPropagation();
    }

    openPhoneEditModal() {
        this.editPhoneValue = '';
        this.activeModal = 'phone';
    }

    handlePhoneValueChange(event) {
        this.editPhoneValue = event.target.value;
    }

    handleVerifyPhone() {
        if (!this.editPhoneValue.trim()) {
            this.showToast('Validation', 'Enter new phone number.', 'warning');
            return;
        }
        this.otpDigits = ['', '', '', ''];
        this.activeModal = 'otp';
    }

    handleOtpInput(event) {
        const index = Number(event.target.dataset.index);
        const cleaned = String(event.target.value || '').replace(/\D/g, '').slice(-1);
        const nextDigits = [...this.otpDigits];
        nextDigits[index] = cleaned;
        this.otpDigits = nextDigits;

        if (cleaned && index < 3) {
            const next = this.template.querySelector(`input[data-index="${index + 1}"]`);
            if (next) {
                next.focus();
            }
        }
    }

    handleOtpKeydown(event) {
        const index = Number(event.target.dataset.index);
        if (event.key === 'Backspace' && !this.otpDigits[index] && index > 0) {
            const prev = this.template.querySelector(`input[data-index="${index - 1}"]`);
            if (prev) {
                prev.focus();
            }
        }
    }

    handleResendOtp() {
        this.showToast('OTP Sent', 'A new OTP has been sent.', 'info');
    }

    handleVerifyOtp() {
        if (this.otpDigits.some((digit) => !digit)) {
            this.showToast('Validation', 'Enter the 4-digit OTP.', 'warning');
            return;
        }

        this.facultyFormData = {
            ...this.facultyFormData,
            phoneNumber: this.editPhoneValue
        };
        this.showSuccessModal('Phone Number Changed!', 'Your phone number has been updated.');
    }

    openEmailEditModal() {
        this.editEmailValue = '';
        this.activeModal = 'email';
    }

    handleEmailValueChange(event) {
        this.editEmailValue = event.target.value;
    }

    handleVerifyEmail() {
        if (!this.editEmailValue.trim()) {
            this.showToast('Validation', 'Enter new email ID.', 'warning');
            return;
        }

        this.facultyFormData = {
            ...this.facultyFormData,
            emailId: this.editEmailValue
        };
        this.showSuccessModal('Email ID Changed!', 'Your email ID has been updated.');
    }

    openPasswordModal() {
        this.currentPasswordInput = '';
        this.newPasswordInput = '';
        this.showCurrentPassword = false;
        this.showNewPassword = false;
        this.activeModal = 'password';
    }

    handleCurrentPasswordChange(event) {
        this.currentPasswordInput = event.target.value;
    }

    handleNewPasswordChange(event) {
        this.newPasswordInput = event.target.value;
    }

    toggleCurrentPasswordVisibility() {
        this.showCurrentPassword = !this.showCurrentPassword;
    }

    toggleNewPasswordVisibility() {
        this.showNewPassword = !this.showNewPassword;
    }

    handleUpdatePassword() {
        if (!this.currentPasswordInput.trim() || !this.newPasswordInput.trim()) {
            this.showToast('Validation', 'Enter current and new password.', 'warning');
            return;
        }

        this.showSuccessModal('Password Changed!', 'Your password has been updated.');
    }

    closeModal() {
        this.activeModal = '';
    }

    openDiscardConfirmModal() {
        this.activeModal = 'discardConfirm';
    }

    confirmFacultyDiscard() {
        this.facultyFormData = { ...DEFAULT_FACULTY_DATA };
        this.closeModal();
    }

    handleSubmitForReview() {
        this.showSuccessModal('Review Request Submitted', 'We will let you know once your request is reviewed');
    }

    showSuccessModal(title, message) {
        this.successTitle = title;
        this.successMessage = message;
        this.activeModal = 'success';
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            if (this.activeModal === 'success') {
                this.activeModal = '';
            }
        }, 1800);
    }

    handleRequestChange(event) {
        const targetName = event.currentTarget.dataset.target;
        this.showToast('Request Raised', `${targetName} change request submitted.`, 'info');
    }

    handleEditPhoto() {
        this.showToast('Photo Update', 'Profile photo update action is ready to be integrated.', 'info');
    }

    handleDiscard() {
        if (this.isFacultyRole) {
            this.facultyFormData = { ...DEFAULT_FACULTY_DATA };
            this.showToast('Changes Discarded', 'Faculty form has been reset.', 'warning');
            return;
        }

        this.formData = { ...DEFAULT_FORM_DATA };
        this.showToast('Changes Discarded', 'Form has been reset.', 'warning');
    }

    handleSave() {
        if (this.isFacultyRole) {
            this.showToast('Submitted', 'Faculty settings submitted for review.', 'success');
            return;
        }

        this.showToast('Changes Saved', 'Student profile settings updated successfully.', 'success');
    }

    toOptions(values, selectedValue = null) {
        return values.map((value) => ({
            label: value,
            value,
            selected: value === selectedValue
        }));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}