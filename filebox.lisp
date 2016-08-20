(in-package :cl-fm)
;; filebox - a widget containing a list of files
(defconstant GTK-KEY-F3 #XFFC0)
(defconstant GTK-KEY-F5 #XFFC2)

(defun print-date (stream date)
  "Given a universal time date, outputs to a stream."
  (if (and date (> date 0))
      (multiple-value-bind (sec min hr day mon yr dow dst-p tz)
	  (decode-universal-time date)
	(declare (ignore sec min hr dow dst-p tz))
	(format stream "~4,'0d-~2,'0d-~2,'0d" yr mon day))
      (format stream "")))

#|(defun fentry-path (fentry directory)
  "convert fentry name into full path"
  (merge-pathnames directory (fentry-name fentry)))
|#

(defparameter *color-q*
  (vector  (make-gdk-color :red 35000 :green 00000 :blue 0) 
	   (make-gdk-color :red 30000 :green 00000 :blue 0) 
	   (make-gdk-color :red 25000 :green 00000 :blue 0) 
	   (make-gdk-color :red 20000 :green 05000 :blue 0) 
	   (make-gdk-color :red 15000 :green 10000 :blue 0) 
	   (make-gdk-color :red 10000 :green 15000 :blue 0) 
	   (make-gdk-color :red 05000 :green 20000 :blue 0) 
	   (make-gdk-color :red 00000 :green 25000 :blue 0) 
	   (make-gdk-color :red 00000 :green 30000 :blue 0) 
	   (make-gdk-color :red 00000 :green 35000 :blue 0)))

(defparameter *color-black* (make-gdk-color :red 0 :green 0 :blue 0) )

(defun q-color (q) ;TODO: range-check q
  (if (= q #XF) *color-black*
      (elt *color-q* q )))



(defstruct filebox widget store path)
  

;;------------------------------------------------------------------------------
;; custom routines - called by renderer
;;
(defun custom-id (column renderer model iterator)
  "id column custom render data function"
  (declare (ignore column))
;  (format t "~A ~%" 	  (gtk-tree-model-get model iterator 1 ))
  (setf (gtk-cell-renderer-text-background-gdk renderer)
	(make-gdk-color :red 65000 :green 0 :blue 0) ) )

(defun custom-name (column renderer model iterator)
  (declare (ignore column))
  
  (setf (gtk-cell-renderer-text-foreground-gdk renderer)
	(q-color (first (gtk-tree-model-get model iterator COL-Q)))))

(defun custom-size (column renderer model iterator)
  (declare (ignore column))
  (let ((size (first (gtk-tree-model-get model iterator COL-SIZE))))
    (if (> size 0)
	(setf (gtk-cell-renderer-text-text renderer)
	      (with-output-to-string (str) (format str "~:d" size))))))

(defun custom-date (column renderer model iterator)
  (declare (ignore column))
  (let ((date (first (gtk-tree-model-get model iterator COL-DATE))))
    (setf (gtk-cell-renderer-text-text renderer)
	  (with-output-to-string (str) (print-date str date))))
;  (format t "DATE")
  )


(defun foreach-selected-file (fb func)
  "func is (lambda (model path iterator).."
  (gtk-tree-selection-selected-foreach
   (gtk-tree-view-get-selection (filebox-widget fb))	;extract selection
   func)
 #| (lambda (model path iterator)
    (let ((pathname (merge-pathnames (filebox-path fb)
				     (gtk-tree-model-get-value model iterator COL-NAME)))))
    (funcall func model path iterator filepath ))
 |#
 )



(defun create-filebox-widget (model)
  "create gtk widget"
  (let ((view (make-instance 'gtk-tree-view
			     :model model))) 
    (loop for column in (create-columns) do
	 (gtk-tree-view-append-column view column))
    (gtk-tree-view-set-rules-hint view 1) ;display stripes
    (gtk-tree-selection-set-mode (gtk-tree-view-get-selection view) :multiple)
    ;invisible columns
    (gtk-tree-view-column-set-visible (gtk-tree-view-get-column view COL-ID) nil)
    ;(gtk-tree-view-column-set-visible (gtk-tree-view-get-column view COL-Q) nil)
    view))


(defun filebox-reload (fb)
  "reload all data"
  (model-refill (filebox-store fb) (filebox-path fb)  ) 
  (model-postprocess (filebox-store fb) (filebox-path fb))
  )
(defun create-filebox (path)
  (let ((fb (make-filebox :path path
			  :store (create-model))))
    (setf (filebox-widget fb)
	  (create-filebox-widget (filebox-store fb))) 

    (model-init (filebox-store fb))
    ;; wiring
    (g-signal-connect
     (filebox-widget fb) "key-press-event"
     (lambda (tv eventkey)
       (declare (ignore tv))
       (format t "PRESS: [~X ~A]~%" (gdk-event-key-keyval eventkey) (gdk-event-key-keyval eventkey))
       (let ((keyval (gdk-event-key-keyval eventkey)))
	 (cond
	   ((eql keyval GTK-KEY-F3)
	    (foreach-selected-file fb (lambda (filename) (format t "~A~%" filename))) )
	   ((eql keyval GTK-KEY-F5) (format t "OK~%")  (filebox-reload fb) )
	   ((and (>= keyval #x30)
		 (<= keyval #x39))
	    (format t "0~%")
	   
	    (foreach-selected-file
	     fb
	     (lambda (model path iterator)
	       (model-set-q model path iterator (filebox-path fb) (- keyval #x30))))
					;(filebox-reload fb)
	    )
	   (t (format t "NOPE")))
	 )
       t ;do not propagate
       ))
    ;; Double-click
    (g-signal-connect
     (filebox-widget fb) "row-activated"
     (lambda (tv path column)
       (format t "~A ~A ~A  ~%" tv path column)
       (let* ((model (gtk-tree-view-get-model tv))
	      (iter (gtk-tree-model-get-iter model path))
	      ;(sel (gtk-tree-view-get-selection tv))
	      (path (merge-pathnames (filebox-path fb)
				     (gtk-tree-model-get-value model iter COL-NAME))))
					;(format t "ITER ~A ~%" path )
	
	 ;TODO: figure out application
	 (external-program:start "vlc" (list path))
	 ;; selected
;	 (gtk-tree-selection-selected-foreach sel (lambda (mod path iter) (format t "MULT SEL ~A~%" (gtk-tree-model-get-value mod iter COL-ID))))
	 )))
     (filebox-reload fb)
    fb)
  )



;-----------------------
