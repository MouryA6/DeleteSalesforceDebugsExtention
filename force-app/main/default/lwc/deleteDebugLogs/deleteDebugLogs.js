import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import hasDeletePermission from '@salesforce/apex/DebugLogManagerController.hasDeletePermission';
import deleteAllDebugLogs from '@salesforce/apex/DebugLogManagerController.deleteAllDebugLogs';

export default class DeleteDebugLogs extends LightningElement {

    @track hasPermission = false;
    @track isLoading     = false;
    @track showConfirm   = false;

    // ── Check permission on load ──────────────────────────────────
    @wire(hasDeletePermission)
    wiredPermission({ data, error }) {
        if (data !== undefined) {
            this.hasPermission = data;
        }
        if (error) {
            console.error('Permission check error:', error);
        }
    }

    // ── Step 1: show confirmation modal ──────────────────────────
    handleDeleteClick() {
        this.showConfirm = true;
    }

    // ── Step 2a: user cancelled ───────────────────────────────────
    handleCancel() {
        this.showConfirm = false;
    }

    // ── Step 2b: user confirmed — call Apex ───────────────────────
    handleConfirm() {
        this.showConfirm = false;
        this.isLoading   = true;

        deleteAllDebugLogs()
            .then(count => {
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({
                    title  : 'Success',
                    message: count + ' debug log(s) deleted successfully.',
                    variant: 'success'
                }));
            })
            .catch(error => {
                this.isLoading = false;
                const msg = error?.body?.message || 'An unexpected error occurred.';
                this.dispatchEvent(new ShowToastEvent({
                    title  : 'Error',
                    message: msg,
                    variant: 'error',
                    mode   : 'sticky'
                }));
            });
    }
}
