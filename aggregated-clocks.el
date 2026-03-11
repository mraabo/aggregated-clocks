;;; aggregated-clock.el --- Aggregate org-clock entries across multiple files

;;; Commentary:
;; This package aggregates org-clock entries from multiple daily timelog files
;; into a single master file, preserving heading hierarchy and grouping
;; activities by their full path.

;;; Code:

(require 'org)
(require 'org-clock)

;;; Customisation

(defgroup aggregated-clock nil
  "Aggregate org-clock entries across multiple files."
  :group 'org
  :prefix "aggregated-clock-")

(defcustom aggregated-clock-source-directory "~/org/timelogs/"
  "Directory containing the daily org files with clock entries."
  :type 'directory
  :group 'aggregated-clock)

(defcustom aggregated-clock-output-file "aggregated_clocks.org"
  "Name of the output file (relative to source directory)."
  :type 'string
  :group 'aggregated-clock)

(defcustom aggregated-clock-exclude-patterns '("aggregated_clocks" "clocktable")
  "List of patterns to exclude from source files.
Files matching any of these patterns will not be processed."
  :type '(repeat string)
  :group 'aggregated-clock)

;;; Helper functions

(defun aggregated-clock--insert-tree (tree level)
  "Recursively insert TREE structure at LEVEL."
  (let ((sorted-keys (sort (hash-table-keys tree)
                          (lambda (a b) (string< (symbol-name a) (symbol-name b))))))
    (dolist (key sorted-keys)
      (let ((value (gethash key tree)))
        (cond
         ;; If value contains :clocks, it's a leaf node with clock entries
         ((plist-get value :clocks)
          (insert (make-string level ?*) " " (symbol-name key) "\n")
          (insert ":LOGBOOK:\n")
          (dolist (entry (reverse (plist-get value :clocks)))
            (insert entry))
          (insert ":END:\n\n"))
         ;; If value is a hash table, it's an intermediate node
         ((hash-table-p value)
          (insert (make-string level ?*) " " (symbol-name key) "\n")
          (aggregated-clock--insert-tree value (1+ level))))))))

;;; Main function

(defun aggregated-clock-aggregate ()
  "Aggregate all clock entries from source files into the output file."
  (interactive)
  (let* ((source-dir (expand-file-name aggregated-clock-source-directory))
         (output-file (expand-file-name aggregated-clock-output-file source-dir))
         (files (directory-files-recursively source-dir "\\.org$"))
         (activity-data (make-hash-table :test 'equal))
         (hierarchy-tracker (make-hash-table :test 'equal)))
    
    ;; Remove excluded files from list
    (setq files (cl-remove-if 
                 (lambda (f)
                   (cl-some (lambda (pattern)
                             (string-match-p pattern (file-name-nondirectory f)))
                           aggregated-clock-exclude-patterns))
                 files))
    
    ;; Collect all clock entries grouped by full heading path
    (dolist (file files)
      (let ((buf (find-file-noselect file)))
        (with-current-buffer buf
          ;; Make sure buffer is up to date from disk
          (revert-buffer t t t)
          (save-excursion
            (goto-char (point-min))
            (while (re-search-forward "^\\*+ " nil t)
              (let* ((level (org-current-level))
                     (heading (org-get-heading t t t t))
                     ;; Get the full outline path
                     (outline-path (org-get-outline-path t))
                     (full-path (mapconcat 'identity outline-path "/"))
                     (element (org-element-at-point))
                     (end (org-entry-end-position)))
                (save-excursion
                  (when (re-search-forward ":LOGBOOK:" end t)
                    (let* ((drawer-start (point))
                           (drawer-end (and (re-search-forward ":END:" end t)
                                           (match-beginning 0)))
                           (clock-content (when drawer-end
                                           (buffer-substring-no-properties 
                                            drawer-start drawer-end))))
                      (when (and clock-content 
                                (string-match-p "CLOCK:" clock-content))
                        (push clock-content
                              (gethash full-path activity-data))
                        ;; Track the outline path for this full-path
                        (puthash full-path outline-path hierarchy-tracker)))))))))))
    
    ;; Close the output file buffer if it's open to avoid conflicts
    (when-let ((output-buf (get-file-buffer output-file)))
      (with-current-buffer output-buf
        (set-buffer-modified-p nil))
      (kill-buffer output-buf))
    
    ;; Build a nested tree structure
    (let ((tree (make-hash-table :test 'eq)))
      (maphash
       (lambda (full-path clock-entries)
         (let* ((outline-path (gethash full-path hierarchy-tracker))
                (current-level tree))
           ;; Navigate/create the tree structure
           (dotimes (i (length outline-path))
             (let* ((heading (nth i outline-path))
                    (heading-symbol (intern heading))
                    (is-last (= i (1- (length outline-path)))))
               (if is-last
                   ;; Last level - store the clock entries
                   (puthash heading-symbol 
                           (list :clocks clock-entries)
                           current-level)
                 ;; Intermediate level - ensure subtree exists
                 (unless (gethash heading-symbol current-level)
                   (puthash heading-symbol (make-hash-table :test 'eq) current-level))
                 (setq current-level (gethash heading-symbol current-level)))))))
       activity-data)
      
      ;; Write to output file
      (with-temp-file output-file
        (insert "#+TITLE: Aggregated Clock Entries\n\n")
        (aggregated-clock--insert-tree tree 1))
      
      (message "Clock entries aggregated to %s (found %d activities)" 
               output-file (hash-table-count activity-data)))))

(provide 'aggregated-clock)

;;; aggregated-clock.el ends here
