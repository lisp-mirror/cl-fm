
(in-package :cl-fm)
;; filebox - a widget containing a list of files
(defstruct filebox widget store path window
	   column-name renderer-name ;for in-place editing of filenames
	   eli selection)

(defun fb-full-namestring (fb pathname)
  "return the namestring to the named file in this fb"
  (uiop:native-namestring
   (truename (merge-pathnames pathname (filebox-path fb)))))

(defun print-date (stream date)
  "Given a universal time date, outputs to a stream."
  (if (and date  (> date 0))
      (multiple-value-bind (sec min hr day mon yr dow dst-p tz)
	  (decode-universal-time date)
	(declare (ignore sec min hr dow dst-p tz))
	(format stream "~4,'0d-~2,'0d-~2,'0d" yr mon day))))
 
  

(defmacro fb-model-value (col)
  "get the value from the model, using lexical 'model' & 'iter'"
  `(gtk-tree-model-get-value model iter ,col))


(defparameter *color-q*
  (make-array 16
	      :element-type 'GDK-COLOR
	      :initial-contents
	      (mapcar #'gdk-color-parse
		      '("#FFFFFF" "#DDFFDB" "#E6F3DA" "#EEE8D9"
			"#F6DCD8" "#FFD1D8" "#FFFFFF" "#FFFFFF"
			"#FFFFFF" "#FFFFFF" "#FFFFFF" "#FFFFFF"
			"#FFFFFF" "#FFFFFF" "#FFFFFF" "#FFFFFF"))))
  
(defparameter *color-black* (make-gdk-color :red 0 :green 0 :blue 0) )
(defparameter *color-white* (gdk-color-parse "#FFFFFF"))

(defun q-color (q) ;TODO: range-check q
  (if (= q #XF) *color-white*
      (elt *color-q*  q )))

  
(defparameter *dragged-onto* nil) 


(defun filebox-reload (fb)
   ;; Refilling the model may take time, so we will set a wait cursor.  In order for
  ;; the cursor redraw to happen, we have to run the refill in idle mode
  (let ((gwin (gdk-screen-get-root-window (gdk-screen-get-default))))
    (flet ((refill-prim ()
	     (unwind-protect
		  (with-slots (store path) fb
		    (model-refill store path  :include-dirs t)   
		    (model-postprocess store path))
	       (gdk::gdk-window-set-cursor gwin (gdk-cursor-new :left-ptr)))))
      ;;
      (with-slots (path window) fb    
	(gdk::gdk-window-set-cursor gwin (gdk-cursor-new :watch))
	(setf (gtk-window-title window) (concatenate 'string "cl-fm  " (namestring path)))
	;; low priority seems to be necessary for the cursor to change
	(g-idle-add #'refill-prim :priority glib:+g-priority-low+)))))


(defun filebox-set-path (fb fpath)
  "set a new path for this filebox and reload"
  (setf (filebox-path fb) fpath)
  (filebox-reload fb))

(defun filebox-up (fb)
  (filebox-set-path
   fb
   (namestring (uiop:pathname-parent-directory-pathname (filebox-path fb)))))


;;==============================================================================
(defun on-row-activated (fb tv path column) ;
  "aka double-click.  Attempt to open file"
  (declare (ignore column))
  (let* ((model (gtk-tree-view-get-model tv))
	 (iter (gtk-tree-model-get-iter model path))
	 (fpath (fb-full-namestring fb (fb-model-value COL-NAME))))
    (format t "ACTIVATED [~A]~%" fpath)

    (when (= (fb-selected-count fb) 1)
      (if (= 1 (fb-model-value COL-DIR))
	  (filebox-set-path fb fpath)
	  (external-program:start "vlc" (list fpath)))))) ;TODO: dispatch on filetype

;;==============================================================================



(defun create-filebox (path window)
  (let ((fb (make-filebox :path nil
			  :store (create-model)
			  :window window
			  )))
    (with-slots (widget selection) fb
      (setf widget (create-filebox-widget fb)) 
      ;; selection
      (setf selection (gtk-tree-view-get-selection widget))
      (gtk-tree-selection-set-mode selection :multiple)


      (drag-and-drop-setup fb)		;see "drag-and-drop.lisp"

      (fb-signal-connect (filebox-widget fb) "row-activated" on-row-activated (tv path column))
      
      
      (filebox-set-path fb path)

      (init-name-editing fb) ;see name-editing.lisp
      fb)))

